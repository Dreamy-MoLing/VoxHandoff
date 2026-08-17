package dev.agenttalk.agent_talk_client

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.GeneralSecurityException
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.UUID

/** Owns non-exportable per-installation device keys in Android Keystore. */
class AndroidKeystoreDeviceKey : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "agent_talk/android_keystore_device_key"
        private const val KEY_ALIAS_PREFIX = "voxhandoff.m6.device."
        private const val KEY_REFERENCE_PATTERN = "^[0-9a-f]{32}$"
        private const val MAX_SIGNING_PAYLOAD_BYTES = 64 * 1024
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "create" -> result.success(create())
                "inspect" -> result.success(inspect(requireReference(call)))
                "sign" -> result.success(sign(call))
                "delete" -> {
                    delete(requireReference(call))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: MissingKeyException) {
            result.error("key_not_found", "The device key does not exist.", null)
        } catch (_: InvalidKeyReferenceException) {
            result.error("invalid_key_reference", "The device key reference is invalid.", null)
        } catch (_: InvalidPayloadException) {
            result.error("invalid_signing_payload", "The device signing payload is invalid.", null)
        } catch (_: StrongBoxUnavailableException) {
            result.error("keystore_unavailable", "Android Keystore is unavailable.", null)
        } catch (_: GeneralSecurityException) {
            result.error("keystore_unavailable", "Android Keystore is unavailable.", null)
        } catch (_: RuntimeException) {
            result.error("keystore_unavailable", "Android Keystore is unavailable.", null)
        }
    }

    private fun create(): Map<String, Any> {
        val reference = newReference()
        val alias = aliasFor(reference)
        var strongBoxBacked = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                try {
                    generate(alias, strongBox = true)
                    strongBoxBacked = true
                } catch (_: StrongBoxUnavailableException) {
                    generate(alias, strongBox = false)
                }
            } else {
                generate(alias, strongBox = false)
            }
            return identity(reference, strongBoxHint = strongBoxBacked)
        } catch (error: Throwable) {
            delete(reference)
            throw error
        }
    }

    private fun generate(alias: String, strongBox: Boolean) {
        val generator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            "AndroidKeyStore",
        )
        val builder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_SIGN,
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(false)
        if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setIsStrongBoxBacked(true)
        }
        generator.initialize(builder.build())
        generator.generateKeyPair()
    }

    private fun inspect(reference: String): Map<String, Any> =
        identity(reference, strongBoxHint = false)

    private fun identity(reference: String, strongBoxHint: Boolean): Map<String, Any> {
        val entry = keyStore().getEntry(aliasFor(reference), null)
            as? KeyStore.PrivateKeyEntry ?: throw MissingKeyException()
        val publicKey = entry.certificate.publicKey.encoded
        val keyInfo = keyInfo(entry.privateKey)
        val hardwareBacked = keyInfo?.isInsideSecureHardware ?: false
        // KeyInfo exposes whether the key is inside secure hardware, but the
        // Android SDK used by this project does not expose a portable
        // StrongBox flag. The create response reports the successful
        // StrongBox attempt; a later inspect reports hardware protection.
        val strongBoxBacked = strongBoxHint
        return mapOf(
            "key_reference" to reference,
            "algorithm" to "ECDSA_P256_SHA256",
            "public_key_spki_der" to publicKey,
            "fingerprint" to "sha256:${hex(sha256(publicKey))}",
            "hardware_backed" to hardwareBacked,
            "strong_box_backed" to strongBoxBacked,
        )
    }

    private fun keyInfo(privateKey: PrivateKey): KeyInfo? = try {
        val factory = KeyFactory.getInstance(privateKey.algorithm, "AndroidKeyStore")
        factory.getKeySpec(privateKey, KeyInfo::class.java)
    } catch (_: GeneralSecurityException) {
        null
    }

    private fun sign(call: MethodCall): ByteArray {
        val reference = requireReference(call)
        val payload = call.argument<ByteArray>("payload")
            ?: throw InvalidPayloadException()
        if (payload.isEmpty() || payload.size > MAX_SIGNING_PAYLOAD_BYTES) {
            throw InvalidPayloadException()
        }
        val entry = keyStore().getEntry(aliasFor(reference), null)
            as? KeyStore.PrivateKeyEntry ?: throw MissingKeyException()
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(entry.privateKey)
        signer.update(payload)
        return signer.sign()
    }

    private fun delete(reference: String) {
        keyStore().deleteEntry(aliasFor(reference))
    }

    private fun requireReference(call: MethodCall): String {
        val reference = call.argument<String>("key_reference")
            ?: throw InvalidKeyReferenceException()
        if (!Regex(KEY_REFERENCE_PATTERN).matches(reference)) {
            throw InvalidKeyReferenceException()
        }
        return reference
    }

    private fun aliasFor(reference: String): String = KEY_ALIAS_PREFIX + reference

    private fun newReference(): String =
        UUID.randomUUID().toString().replace("-", "").lowercase()

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply {
        load(null)
    }

    private fun sha256(value: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(value)

    private fun hex(value: ByteArray): String = value.joinToString("") {
        "%02x".format(it)
    }

    private class MissingKeyException : Exception()
    private class InvalidKeyReferenceException : Exception()
    private class InvalidPayloadException : Exception()
}
