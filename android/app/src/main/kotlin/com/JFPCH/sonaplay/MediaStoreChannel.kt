package com.JFPCH.sonaplay

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import androidx.activity.ComponentActivity
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Channel "sonaplay/media": song listing, artwork and real deletion through MediaStore.
 * Replaces the unmaintained on_audio_query plugin.
 *
 * Must be created during Activity construction (field initializer) because it
 * registers an ActivityResult launcher for the system delete confirmation.
 */
class MediaStoreChannel(private val activity: ComponentActivity) {
    private val resolver get() = activity.contentResolver
    private val collection: Uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** Continuation run when the user answers the system delete dialog (true = allowed). */
    private var onDeleteAnswer: ((Boolean) -> Unit)? = null

    private val deleteLauncher = activity.registerForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult()
    ) { answer ->
        val next = onDeleteAnswer
        onDeleteAnswer = null
        next?.invoke(answer.resultCode == Activity.RESULT_OK)
    }

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, "sonaplay/media").setMethodCallHandler { call, result ->
            when (call.method) {
                "querySongs" -> background(result) { querySongs() }
                "artwork" -> {
                    val id = call.argument<Number>("id")!!.toLong()
                    val size = call.argument<Int>("size") ?: 300
                    background(result) { artwork(id, size) }
                }
                "deleteSongs" -> {
                    val ids = call.argument<List<Number>>("ids")!!.map { it.toLong() }
                    deleteSongs(ids, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("MEDIA_ERROR", e.message, null) }
            }
        }
    }

    private fun querySongs(): List<Map<String, Any?>> {
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DATA,
        )
        val songs = mutableListOf<Map<String, Any?>>()
        resolver.query(
            collection, projection,
            "${MediaStore.Audio.Media.IS_MUSIC} != 0", null,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
        )?.use { c ->
            while (c.moveToNext()) {
                val artist = c.getString(2)
                songs.add(
                    mapOf(
                        "id" to c.getLong(0),
                        "title" to (c.getString(1) ?: ""),
                        "artist" to if (artist == MediaStore.UNKNOWN_STRING) null else artist,
                        "album" to c.getString(3),
                        "albumId" to c.getLong(4),
                        "duration" to c.getLong(5),
                        "dateAdded" to c.getLong(6),
                        "path" to c.getString(7),
                    )
                )
            }
        }
        return songs
    }

    /** JPEG bytes of the song's embedded artwork, or null when it has none. */
    private fun artwork(id: Long, size: Int): ByteArray? {
        val uri = ContentUris.withAppendedId(collection, id)
        val bitmap: Bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                resolver.loadThumbnail(uri, Size(size, size), null)
            } catch (e: java.io.IOException) {
                return null
            }
        } else {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(activity, uri)
                val bytes = retriever.embeddedPicture ?: return null
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
            } finally {
                retriever.release()
            }
        }
        return ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it)
            it.toByteArray()
        }
    }

    /**
     * Deletes the files behind [ids]. Android 11+ shows one system confirmation for all
     * of them; Android 10 asks per file; Android 9 and below delete directly (needs
     * WRITE_EXTERNAL_STORAGE). Answers with the IDs that are really gone, so a cancelled
     * dialog leaves the app state untouched.
     */
    private fun deleteSongs(ids: List<Long>, result: MethodChannel.Result) {
        if (onDeleteAnswer != null) {
            result.error("BUSY", "A delete request is already in progress", null)
            return
        }
        val uris = ids.map { ContentUris.withAppendedId(collection, it) }
        val finish = { background(result) { ids.filterNot(::exists).map { it.toString() } } }

        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                val request = MediaStore.createDeleteRequest(resolver, uris)
                onDeleteAnswer = { finish() }
                deleteLauncher.launch(IntentSenderRequest.Builder(request.intentSender).build())
            }
            Build.VERSION.SDK_INT == Build.VERSION_CODES.Q -> deleteOneByOne(uris, 0, finish)
            else -> io.execute {
                uris.forEach { uri ->
                    val path = pathOf(uri)
                    try {
                        resolver.delete(uri, null, null)
                        path?.let { File(it).delete() }
                    } catch (e: SecurityException) {
                        // ponytail: skipped when WRITE_EXTERNAL_STORAGE is missing; Dart requests it first
                    }
                }
                main.post(finish)
            }
        }
    }

    /** Android 10: each foreign file needs its own RecoverableSecurityException round trip. */
    private fun deleteOneByOne(uris: List<Uri>, index: Int, finish: () -> Unit) {
        if (index >= uris.size) return finish()
        try {
            resolver.delete(uris[index], null, null)
            deleteOneByOne(uris, index + 1, finish)
        } catch (e: SecurityException) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || e !is RecoverableSecurityException) {
                return deleteOneByOne(uris, index + 1, finish)
            }
            onDeleteAnswer = { allowed ->
                // Allowed: retry the same file with the granted access; denied: skip it
                deleteOneByOne(uris, if (allowed) index else index + 1, finish)
            }
            deleteLauncher.launch(
                IntentSenderRequest.Builder(e.userAction.actionIntent.intentSender).build()
            )
        }
    }

    private fun exists(id: Long): Boolean = resolver.query(
        ContentUris.withAppendedId(collection, id), arrayOf(MediaStore.Audio.Media._ID),
        null, null, null
    )?.use { it.count > 0 } ?: false

    private fun pathOf(uri: Uri): String? = resolver.query(
        uri, arrayOf(MediaStore.Audio.Media.DATA), null, null, null
    )?.use { if (it.moveToFirst()) it.getString(0) else null }
}
