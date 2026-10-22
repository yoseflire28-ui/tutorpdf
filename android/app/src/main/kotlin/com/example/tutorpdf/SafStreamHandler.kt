package com.example.tutorpdf

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class SafStreamHandler(private val context: Context) {
    
    companion object {
        private const val CHANNEL = "com.tutorpdf/saf_reader"
        private const val BUFFER_SIZE = 8192 // 8KB buffer for streaming
    }
    
    /**
     * Read file bytes directly from SAF URI without copying to disk
     * This provides zero-copy access to content:// URIs
     */
    fun readSafFile(uriString: String): ByteArray? {
        return try {
            val uri = Uri.parse(uriString)
            val contentResolver: ContentResolver = context.contentResolver
            
            contentResolver.openInputStream(uri)?.use { inputStream ->
                val buffer = ByteArray(BUFFER_SIZE)
                val outputStream = ByteArrayOutputStream()
                var bytesRead: Int
                
                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                }
                
                outputStream.toByteArray()
            }
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * Read first N bytes for magic byte detection
     */
    fun readSafFileHeader(uriString: String, byteCount: Int = 16): ByteArray? {
        return try {
            val uri = Uri.parse(uriString)
            val contentResolver: ContentResolver = context.contentResolver
            
            contentResolver.openInputStream(uri)?.use { inputStream ->
                val buffer = ByteArray(byteCount)
                val bytesRead = inputStream.read(buffer)
                if (bytesRead > 0) {
                    buffer.copyOf(bytesRead)
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * Get file size from SAF URI
     */
    fun getSafFileSize(uriString: String): Long? {
        return try {
            val uri = Uri.parse(uriString)
            val contentResolver: ContentResolver = context.contentResolver
            
            contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                pfd.statSize
            }
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * Check if URI is a valid SAF content URI
     */
    fun isValidSafUri(uriString: String): Boolean {
        return try {
            val uri = Uri.parse(uriString)
            uri.scheme == "content" && uri.authority != null
        } catch (e: Exception) {
            false
        }
    }

    fun takePersistableUriPermission(uriString: String) {
        val uri = Uri.parse(uriString)
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        context.contentResolver.takePersistableUriPermission(uri, flags)
    }

    /**
     * Get MIME type from content URI via ContentResolver
     */
    fun getMimeType(uriString: String): String? {
        return try {
            val uri = Uri.parse(uriString)
            context.contentResolver.getType(uri)
        } catch (e: Exception) {
            null
        }
    }
}

/**
 * MethodChannel handler for Flutter communication
 */
class SafStreamMethodChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    
    private val safHandler = SafStreamHandler(context)
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getMimeType" -> {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    val mimeType = safHandler.getMimeType(uriString)
                    result.success(mimeType)
                } else {
                    result.error("INVALID_ARGUMENT", "URI argument is required", null)
                }
            }
            "readSafFile" -> {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    val bytes = safHandler.readSafFile(uriString)
                    if (bytes != null) {
                        result.success(bytes)
                    } else {
                        result.error("READ_FAILED", "Failed to read SAF file", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "URI argument is required", null)
                }
            }
            "readSafFileHeader" -> {
                val uriString = call.argument<String>("uri")
                val byteCount = call.argument<Int>("byteCount") ?: 16
                if (uriString != null) {
                    val bytes = safHandler.readSafFileHeader(uriString, byteCount)
                    if (bytes != null) {
                        result.success(bytes)
                    } else {
                        result.error("READ_FAILED", "Failed to read SAF file header", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "URI argument is required", null)
                }
            }
            "getSafFileSize" -> {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    val size = safHandler.getSafFileSize(uriString)
                    if (size != null) {
                        result.success(size)
                    } else {
                        result.error("READ_FAILED", "Failed to get SAF file size", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "URI argument is required", null)
                }
            }
            "isValidSafUri" -> {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    result.success(safHandler.isValidSafUri(uriString))
                } else {
                    result.error("INVALID_ARGUMENT", "URI argument is required", null)
                }
            }
            "takePersistableUriPermission" -> {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    safHandler.takePersistableUriPermission(uriString)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "URI argument is required", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}
