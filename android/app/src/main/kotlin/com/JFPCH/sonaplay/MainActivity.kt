package com.JFPCH.sonaplay

import android.content.ContentValues
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import com.ryanheise.audioservice.AudioServiceFragmentActivity

class MainActivity: AudioServiceFragmentActivity() {
    private val CHANNEL = "sonaplay/ringtone"
    private val uiThreadHandler = Handler(Looper.getMainLooper())
    private val mediaStore = MediaStoreChannel(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaStore.attach(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setAndroidRingtone") {
                val filePath = call.argument<String>("path") ?: return@setMethodCallHandler
                val startTimeMs = call.argument<Int>("startTimeMs") ?: 0
                val endTimeMs = call.argument<Int>("endTimeMs") ?: 0
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(this)) {
                    val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                    intent.data = Uri.parse("package:" + this.packageName)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    this.startActivity(intent)
                    result.error("PERMISSIONS_REQUIRED", "El permiso WRITE_SETTINGS fue denegado.", null)
                    return@setMethodCallHandler
                }

                // El procesamiento de MediaCodec no debe bloquear el hilo de Interfaz de Usuario
                Thread {
                    try {
                        val trimmedFile = trimAudioFile(filePath, startTimeMs, endTimeMs)
                        if (trimmedFile != null) {
                            val success = setRingtoneFromStorage(trimmedFile)
                            uiThreadHandler.post {
                                if (success) {
                                    result.success(true)
                                } else {
                                    result.error("MEDIASTORE_ERROR", "No se pudo insertar en MediaStore", null)
                                }
                            }
                        } else {
                            uiThreadHandler.post {
                                result.error("TRIM_ERROR", "Error recortando el archivo. Puede que el formato sea incompatible.", null)
                            }
                        }
                    } catch (e: Exception) {
                        uiThreadHandler.post {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun trimAudioFile(inputFilePath: String, startTimeMs: Int, endTimeMs: Int): File? {
        val inFile = File(inputFilePath)
        if (!inFile.exists()) return null

        val outDir = cacheDir
        
        var extractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null
        var outputStream: java.io.FileOutputStream? = null

        try {
            extractor = MediaExtractor()
            extractor.setDataSource(inFile.absolutePath)

            val trackCount = extractor.trackCount
            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null
            var mimeType = ""

            for (i in 0 until trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = format
                    mimeType = mime
                    break
                }
            }

            if (audioTrackIndex < 0 || audioFormat == null) return null
            extractor.selectTrack(audioTrackIndex)
            
            val startUs = startTimeMs * 1000L
            val endUs = endTimeMs * 1000L
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

            val isMp3 = mimeType == "audio/mpeg"
            val outFile = if (isMp3) {
                File(outDir, "trimmed_ringtone_${System.currentTimeMillis()}.mp3")
            } else {
                File(outDir, "trimmed_ringtone_${System.currentTimeMillis()}.m4a")
            }

            // Asignar un buffer de max size (depende del codec, por default 1MB)
            val bufferSize = audioFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 1024 * 1024)
            val buffer = ByteBuffer.allocate(bufferSize)
            val bufferInfo = MediaCodec.BufferInfo()

            var muxerTrackIndex = -1

            if (isMp3) {
                // MP3 se exporta transmitiendo en crudo los trozos desde el Extractor hacia un Stream (Bypass Muxer)
                outputStream = java.io.FileOutputStream(outFile)
            } else {
                // Contenedor MP4 para AAC (M4A) usando MediaMuxer
                muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                muxerTrackIndex = muxer.addTrack(audioFormat)
                muxer.start()
            }

            while (true) {
                bufferInfo.size = extractor.readSampleData(buffer, 0)
                if (bufferInfo.size < 0) {
                    break
                }
                
                val presentationTimeUs = extractor.sampleTime
                if (endUs > 0 && presentationTimeUs > endUs) {
                    break
                }

                if (isMp3) {
                    val chunk = ByteArray(bufferInfo.size)
                    buffer.get(chunk)
                    buffer.clear()
                    outputStream?.write(chunk)
                } else {
                    bufferInfo.presentationTimeUs = presentationTimeUs
                    bufferInfo.offset = 0
                    bufferInfo.flags = extractor.sampleFlags
                    muxer?.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
                }
                
                extractor.advance()
            }

            return outFile
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        } finally {
            try { extractor?.release() } catch (e: Exception) {}
            try { 
                muxer?.stop() 
                muxer?.release()
            } catch (e: Exception) {}
            try { outputStream?.close() } catch (e: Exception) {}
        }
    }

    private fun setRingtoneFromStorage(file: File): Boolean {
        try {
            val isMp3 = file.name.endsWith(".mp3")
            val mime = if (isMp3) "audio/mpeg" else "audio/mp4"
            val title = "SonaPlay Ringtone"
            val fileName = "SonaPlay_Ringtone_${System.currentTimeMillis()}.${if (isMp3) "mp3" else "m4a"}"

            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.TITLE, title)
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mime) 
                put(MediaStore.Audio.Media.IS_RINGTONE, true)
                put(MediaStore.Audio.Media.IS_ALARM, false)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
                put(MediaStore.Audio.Media.IS_MUSIC, false)
            }

            val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            var newUri: Uri? = null

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // API 29+: Usar RELATIVE_PATH y OutputStream para insertar directamente sin exponer la ruta privada
                values.put(MediaStore.Audio.Media.RELATIVE_PATH, android.os.Environment.DIRECTORY_RINGTONES)
                newUri = this.contentResolver.insert(uri, values) 
                if (newUri != null) {
                    this.contentResolver.openOutputStream(newUri)?.use { outStream ->
                        file.inputStream().use { it.copyTo(outStream) }
                    }
                }
            } else {
                // API < 29: Requiere colocar el archivo en un directorio público accesible por RingtoneManager
                val ringtoneDir = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_RINGTONES)
                var targetDir = ringtoneDir
                if (!targetDir.exists() && !targetDir.mkdirs()) {
                    targetDir = getExternalFilesDir(android.os.Environment.DIRECTORY_RINGTONES)
                }
                
                if (targetDir != null) {
                    if (!targetDir.exists()) targetDir.mkdirs()
                    val targetFile = File(targetDir, fileName)
                    file.copyTo(targetFile, overwrite = true)
                    
                    values.put(MediaStore.MediaColumns.DATA, targetFile.absolutePath)
                    newUri = this.contentResolver.insert(uri, values)
                }
            }
            
            if (newUri == null) {
                return false
            }

            RingtoneManager.setActualDefaultRingtoneUri(this, RingtoneManager.TYPE_RINGTONE, newUri)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}
