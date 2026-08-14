package dev.agenttalk.agent_talk_client

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "agent_talk/private_ca_certificate"
        private const val PICK_CERTIFICATE = 4301
        private const val MAX_CERTIFICATE_BYTES = 131072
    }

    private var pendingCertificateResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickPrivateCaCertificate" -> pickPrivateCaCertificate(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickPrivateCaCertificate(result: MethodChannel.Result) {
        if (pendingCertificateResult != null) {
            result.error("picker_busy", "A certificate picker is already open.", null)
            return
        }
        pendingCertificateResult = result
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        try {
            startActivityForResult(intent, PICK_CERTIFICATE)
        } catch (_: Exception) {
            pendingCertificateResult = null
            result.error(
                "picker_unavailable",
                "Certificate file import is unavailable.",
                null,
            )
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_CERTIFICATE) return

        val result = pendingCertificateResult ?: return
        pendingCertificateResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        try {
            val bytes = contentResolver.openInputStream(data.data!!)?.use(::readBounded)
            if (bytes == null) {
                result.error("certificate_read_failed", "Certificate file could not be read.", null)
            } else {
                result.success(bytes)
            }
        } catch (_: CertificateTooLargeException) {
            result.error(
                "certificate_too_large",
                "The certificate file is too large.",
                null,
            )
        } catch (_: Exception) {
            result.error(
                "certificate_read_failed",
                "Certificate file could not be read.",
                null,
            )
        }
    }

    private fun readBounded(input: java.io.InputStream): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        var total = 0
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            total += count
            if (total > MAX_CERTIFICATE_BYTES) throw CertificateTooLargeException()
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    private class CertificateTooLargeException : Exception()

    override fun onDestroy() {
        pendingCertificateResult?.error(
            "activity_destroyed",
            "Certificate file import was cancelled.",
            null,
        )
        pendingCertificateResult = null
        super.onDestroy()
    }
}
