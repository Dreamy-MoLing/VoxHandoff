package dev.agenttalk.agent_talk_client

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max
import kotlin.math.sqrt

class AndroidAudioCapture(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private const val CONTROL_CHANNEL = "agent_talk/android_audio_capture"
        private const val EVENT_CHANNEL = "agent_talk/android_audio_capture_events"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_COUNT = 1
        private const val BYTES_PER_SAMPLE = 2
        private const val READ_SIZE = 3200
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val controlChannel = MethodChannel(messenger, CONTROL_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    @Volatile
    private var eventSink: EventChannel.EventSink? = null
    @Volatile
    private var running = false
    @Volatile
    private var discarding = false
    private var prepared = false
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null

    init {
        controlChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call, result)
            "stop" -> finish(result, discard = false)
            "cancel" -> finish(result, discard = true)
            "dispose" -> {
                finish(null, discard = true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        if (prepared) beginCapture()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        if (prepared || captureThread != null) finish(null, discard = true)
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        if (prepared || captureThread != null) {
            result.error("session_conflict", "Another recording is active.", null)
            return
        }
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("permission_denied", "Microphone permission is not granted.", null)
            return
        }

        val sampleRate = (call.argument<Number>("sampleRate") ?: SAMPLE_RATE).toInt()
        val channels = (call.argument<Number>("channels") ?: CHANNEL_COUNT).toInt()
        if (sampleRate != SAMPLE_RATE || channels != CHANNEL_COUNT) {
            result.error("format_unsupported", "Android capture requires 16 kHz mono PCM.", null)
            return
        }

        val minimumBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minimumBuffer <= 0) {
            result.error("recording_device_unavailable", "Audio input is unavailable.", null)
            return
        }

        val record = createAudioRecord(max(minimumBuffer, READ_SIZE * 2))
        if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
            record?.release()
            result.error("recording_device_unavailable", "Audio input is unavailable.", null)
            return
        }

        audioRecord = record
        prepared = true
        discarding = false
        beginCapture()
        result.success(null)
    }

    private fun createAudioRecord(bufferSize: Int): AudioRecord? {
        val sources = intArrayOf(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC,
        )
        for (source in sources) {
            try {
                val record = AudioRecord.Builder()
                    .setAudioSource(source)
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(SAMPLE_RATE)
                            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                            .build(),
                    )
                    .setBufferSizeInBytes(bufferSize)
                    .build()
                if (record.state == AudioRecord.STATE_INITIALIZED) return record
                record.release()
            } catch (_: RuntimeException) {
                // Try the explicit MIC source if VOICE_RECOGNITION is unavailable.
            }
        }
        return null
    }

    private fun beginCapture() {
        val record = audioRecord ?: return
        if (!prepared || eventSink == null || captureThread != null) return
        try {
            record.startRecording()
            if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                throw IllegalStateException("AudioRecord did not enter recording state.")
            }
        } catch (_: RuntimeException) {
            releaseCapture()
            eventSink?.error("recording_start_failed", "Audio input could not start.", null)
            return
        }

        running = true
        val thread = Thread({ readLoop(record) }, "voxhandoff-audio-record")
        captureThread = thread
        thread.start()
    }

    private fun readLoop(record: AudioRecord) {
        val buffer = ByteArray(READ_SIZE)
        while (running) {
            val count = try {
                record.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
            } catch (_: RuntimeException) {
                running = false
                postStreamError()
                break
            }
            if (count > 0) {
                val pcm = buffer.copyOf(count)
                val level = rmsLevel(pcm)
                mainHandler.post {
                    val sink = eventSink
                    if (sink != null && !discarding) {
                        sink.success(mapOf("pcm" to pcm, "level" to level))
                    }
                }
            } else if (count < 0) {
                running = false
                postStreamError()
                break
            }
        }
    }

    private fun postStreamError() {
        mainHandler.post {
            if (!discarding) {
                eventSink?.error("audio_read_failed", "Audio input could not be read.", null)
            }
        }
    }

    private fun rmsLevel(pcm: ByteArray): Double {
        val samples = pcm.size / BYTES_PER_SAMPLE
        if (samples == 0) return 0.0
        var sum = 0.0
        for (index in 0 until samples) {
            val low = pcm[index * 2].toInt() and 0xff
            val high = pcm[index * 2 + 1].toInt()
            val raw = (high shl 8) or low
            val signed = if (raw > 32767) raw - 65536 else raw
            val normalized = signed / 32768.0
            sum += normalized * normalized
        }
        return (sqrt(sum / samples)).coerceIn(0.0, 1.0)
    }

    private fun finish(result: MethodChannel.Result?, discard: Boolean) {
        discarding = discard
        running = false
        val record = audioRecord
        val thread = captureThread
        if (record == null || thread == null) {
            releaseCapture()
            result?.success(null)
            return
        }

        var stopFailed = false
        try {
            record.stop()
        } catch (_: RuntimeException) {
            stopFailed = true
        }
        Thread {
            var joinFailed = false
            try {
                thread.join(1000)
                if (thread.isAlive) {
                    thread.interrupt()
                    joinFailed = true
                }
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                joinFailed = true
            }
            mainHandler.post {
                releaseCapture()
                if (result == null) return@post
                if (stopFailed || joinFailed) {
                    result.error("recording_stop_failed", "Audio input could not stop.", null)
                } else {
                    result.success(null)
                }
            }
        }.start()
    }

    private fun releaseCapture() {
        running = false
        prepared = false
        captureThread = null
        audioRecord?.release()
        audioRecord = null
    }

    fun dispose() {
        controlChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        finish(null, discard = true)
    }
}
