package dev.agenttalk.agent_talk_client

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
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
        private const val TAG = "VoxHandoffAudio"
        private const val CONTROL_CHANNEL = "agent_talk/android_audio_capture"
        private const val EVENT_CHANNEL = "agent_talk/android_audio_capture_events"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_COUNT = 1
        private const val BYTES_PER_SAMPLE = 2
        private const val READ_SIZE = 3200
        private const val MAX_DIAGNOSTIC_LOGS = 20
        private const val START_SINK_TIMEOUT_MS = 2000L
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
    private var pendingStartResult: MethodChannel.Result? = null
    private var pendingStartTimeout: Runnable? = null
    private var readDiagnosticCount = 0
    private var pushDiagnosticCount = 0

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
        Log.i(
            TAG,
            "onListen sinkNullBefore=${eventSink == null} prepared=$prepared " +
                "discarding=$discarding",
        )
        eventSink = events
        if (prepared && beginCapture()) completePendingStartSuccess()
    }

    override fun onCancel(arguments: Any?) {
        Log.i(
            TAG,
            "onCancel prepared=$prepared captureThread=${captureThread != null} " +
                "discarding=$discarding",
        )
        eventSink = null
        if (prepared || captureThread != null) finish(null, discard = true)
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        Log.i(TAG, "start requested sinkNull=${eventSink == null} prepared=$prepared")
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
        pendingStartResult = result
        readDiagnosticCount = 0
        pushDiagnosticCount = 0
        Log.i(
            TAG,
            "prepare complete sinkNull=${eventSink == null} discarding=$discarding",
        )
        if (beginCapture()) {
            completePendingStartSuccess()
        } else if (eventSink == null) {
            val timeout = Runnable {
                if (pendingStartResult == null) return@Runnable
                Log.i(TAG, "start sink wait timeout sinkNull=true discarding=$discarding")
                completePendingStartError(
                    "recording_stream_unavailable",
                    "Audio event stream did not become ready.",
                )
                releaseCapture()
            }
            pendingStartTimeout = timeout
            mainHandler.postDelayed(timeout, START_SINK_TIMEOUT_MS)
        }
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

    private fun beginCapture(): Boolean {
        val record = audioRecord
        if (record == null || !prepared || eventSink == null || captureThread != null) {
            Log.i(
                TAG,
                "beginCapture skipped record=${record != null} prepared=$prepared " +
                    "sinkNull=${eventSink == null} captureThread=${captureThread != null}",
            )
            return false
        }
        Log.i(TAG, "beginCapture attempt sinkNull=false discarding=$discarding")
        try {
            record.startRecording()
            if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                throw IllegalStateException("AudioRecord did not enter recording state.")
            }
        } catch (_: RuntimeException) {
            Log.i(TAG, "beginCapture failed discarding=$discarding")
            releaseCapture()
            eventSink?.error("recording_start_failed", "Audio input could not start.", null)
            completePendingStartError(
                "recording_start_failed",
                "Audio input could not start.",
            )
            return false
        }

        running = true
        val thread = Thread({ readLoop(record) }, "voxhandoff-audio-record")
        captureThread = thread
        thread.start()
        Log.i(TAG, "beginCapture started captureThread=true discarding=$discarding")
        return true
    }

    private fun readLoop(record: AudioRecord) {
        val buffer = ByteArray(READ_SIZE)
        while (running) {
            val count = try {
                record.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
            } catch (_: RuntimeException) {
                Log.i(TAG, "readLoop read=exception sinkNull=${eventSink == null} discarding=$discarding")
                running = false
                postStreamError()
                break
            }
            if (readDiagnosticCount < MAX_DIAGNOSTIC_LOGS) {
                readDiagnosticCount += 1
                Log.i(
                    TAG,
                    "readLoop readCount=$count sinkNull=${eventSink == null} " +
                        "discarding=$discarding",
                )
            }
            if (count > 0) {
                val pcm = buffer.copyOf(count)
                val level = rmsLevel(pcm)
                mainHandler.post {
                    val sink = eventSink
                    val sinkNull = sink == null
                    val discarded = discarding
                    if (sink != null && !discarded) {
                        try {
                            sink.success(mapOf("pcm" to pcm, "level" to level))
                            if (pushDiagnosticCount < MAX_DIAGNOSTIC_LOGS) {
                                pushDiagnosticCount += 1
                                Log.i(
                                    TAG,
                                    "push success bytes=$count sinkNull=false discarding=false",
                                )
                            }
                        } catch (_: RuntimeException) {
                            if (pushDiagnosticCount < MAX_DIAGNOSTIC_LOGS) {
                                pushDiagnosticCount += 1
                                Log.i(
                                    TAG,
                                    "push failed bytes=$count sinkNull=false discarding=false",
                                )
                            }
                        }
                    } else if (pushDiagnosticCount < MAX_DIAGNOSTIC_LOGS) {
                        pushDiagnosticCount += 1
                        Log.i(
                            TAG,
                            "push skipped bytes=$count sinkNull=$sinkNull discarding=$discarded",
                        )
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
            Log.i(TAG, "postStreamError sinkNull=${eventSink == null} discarding=$discarding")
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
        Log.i(
            TAG,
            "finish discard=$discard prepared=$prepared captureThread=${captureThread != null} " +
                "sinkNull=${eventSink == null}",
        )
        discarding = discard
        running = false
        if (pendingStartResult != null) {
            completePendingStartError(
                "recording_start_cancelled",
                "Audio capture start was cancelled.",
            )
        }
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
                Log.i(
                    TAG,
                    "finish complete discard=$discard stopFailed=$stopFailed " +
                        "joinFailed=$joinFailed",
                )
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

    private fun completePendingStartSuccess() {
        val result = pendingStartResult ?: return
        pendingStartResult = null
        pendingStartTimeout?.let(mainHandler::removeCallbacks)
        pendingStartTimeout = null
        Log.i(TAG, "start success sinkNull=false captureThread=${captureThread != null}")
        result.success(null)
    }

    private fun completePendingStartError(code: String, message: String) {
        val result = pendingStartResult ?: return
        pendingStartResult = null
        pendingStartTimeout?.let(mainHandler::removeCallbacks)
        pendingStartTimeout = null
        Log.i(TAG, "start error code=$code sinkNull=${eventSink == null} discarding=$discarding")
        result.error(code, message, null)
    }

    fun dispose() {
        controlChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        finish(null, discard = true)
    }
}
