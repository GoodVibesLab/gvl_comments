package com.goodvibeslab.gvl_comments

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/**
 * Native bridge for gvl_comments.
 *
 * Exposes the app install binding used by the backend to prevent API key reuse
 * across unrelated apps.
 *
 * Methods:
 * - getInstallBinding -> { packageName: String, sha256: String }
 */
class GvlCommentsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "gvl_comments")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstallBinding" -> {
                try {
                    val packageName = applicationContext.packageName
                    val sha256 = getAppSigningSha256Hex(applicationContext)

                    val map = hashMapOf<String, Any?>(
                        "packageName" to packageName,
                        "sha256" to sha256
                    )
                    result.success(map)
                } catch (t: Throwable) {
                    // Best-effort: still return the package name so the Dart side can log/diagnose.
                    val map = hashMapOf<String, Any?>(
                        "packageName" to applicationContext.packageName,
                        "sha256" to null
                    )
                    result.success(map)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun getAppSigningSha256Hex(context: Context): String {
        val pm = context.packageManager
        val pkg = context.packageName

        val packageInfo: PackageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pm.getPackageInfo(pkg, PackageManager.GET_SIGNING_CERTIFICATES)
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(pkg, PackageManager.GET_SIGNATURES)
        }

        val certBytes: ByteArray = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = packageInfo.signingInfo
                ?: throw IllegalStateException("SigningInfo unavailable")

            val signatures = if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }

            require(signatures.isNotEmpty()) { "No signatures found" }
            signatures[0].toByteArray()
        } else {
            @Suppress("DEPRECATION")
            val signatures = packageInfo.signatures
            require(!signatures.isNullOrEmpty()) { "No signatures found" }
            signatures[0].toByteArray()
        }

        // Hash it with SHA-256.
        val digest = MessageDigest.getInstance("SHA-256").digest(certBytes)
        return digest.toHexUpper()
    }

    private fun ByteArray.toHexUpper(): String {
        val sb = StringBuilder(size * 2)
        for (b in this) {
            sb.append(String.format("%02X", b))
        }
        return sb.toString()
    }
}