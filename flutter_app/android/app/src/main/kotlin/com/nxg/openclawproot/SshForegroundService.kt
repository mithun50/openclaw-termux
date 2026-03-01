package com.nxg.openclawproot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.NetworkInterface

/**
 * Foreground service that runs sshd in a persistent proot process.
 * sshd must run with -D (no daemonize) so proot stays alive.
 */
class SshForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "openclaw_ssh"
        const val NOTIFICATION_ID = 5
        const val EXTRA_PORT = "port"
        var isRunning = false
            private set
        var currentPort = 8022
            private set
        private var instance: SshForegroundService? = null

        fun start(context: Context, port: Int = 8022) {
            val intent = Intent(context, SshForegroundService::class.java).apply {
                putExtra(EXTRA_PORT, port)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, SshForegroundService::class.java)
            context.stopService(intent)
        }

        /** Get device IP addresses via Android NetworkInterface. */
        fun getDeviceIps(): List<String> {
            val ips = mutableListOf<String>()
            try {
                val interfaces = NetworkInterface.getNetworkInterfaces() ?: return ips
                for (iface in interfaces) {
                    if (iface.isLoopback || !iface.isUp) continue
                    for (addr in iface.inetAddresses) {
                        if (addr.isLoopbackAddress) continue
                        val hostAddr = addr.hostAddress ?: continue
                        // Skip IPv6 link-local
                        if (hostAddr.contains("%")) continue
                        // Prefer IPv4, but include IPv6 too
                        ips.add(hostAddr)
                    }
                }
            } catch (_: Exception) {}
            return ips
        }
    }

    private var sshdProcess: Process? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val port = intent?.getIntExtra(EXTRA_PORT, 8022) ?: 8022
        currentPort = port
        startForeground(NOTIFICATION_ID, buildNotification("Starting SSH on port $port..."))
        acquireWakeLock()
        startSshd(port)
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        stopSshd()
        releaseWakeLock()
        super.onDestroy()
    }

    private fun startSshd(port: Int) {
        isRunning = true
        instance = this

        Thread {
            try {
                val filesDir = applicationContext.filesDir.absolutePath
                val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir
                val pm = ProcessManager(filesDir, nativeLibDir)

                // Ensure directories exist
                val bootstrapManager = BootstrapManager(applicationContext, filesDir, nativeLibDir)
                try { bootstrapManager.setupDirectories() } catch (_: Exception) {}
                try { bootstrapManager.writeResolvConf() } catch (_: Exception) {}

                // Generate host keys if missing, configure sshd, then run in
                // foreground mode (-D) so the proot process stays alive.
                // -e logs to stderr instead of syslog (easier debugging).
                // PermitRootLogin yes is needed since proot fakes root.
                val cmd = "mkdir -p /run/sshd /etc/ssh && " +
                    "test -f /etc/ssh/ssh_host_rsa_key || ssh-keygen -A && " +
                    "sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null; " +
                    "grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config; " +
                    "/usr/sbin/sshd -D -e -p $port"

                sshdProcess = pm.startProotProcess(cmd)
                updateNotification("SSH running on port $port")

                // Read stderr for logs
                val stderrReader = BufferedReader(InputStreamReader(sshdProcess!!.errorStream))
                Thread {
                    try {
                        var line: String?
                        while (stderrReader.readLine().also { line = it } != null) {
                            // Could log these if needed
                        }
                    } catch (_: Exception) {}
                }.start()

                val exitCode = sshdProcess!!.waitFor()
                isRunning = false
                updateNotification("SSH stopped (exit $exitCode)")
                stopSelf()
            } catch (e: Exception) {
                isRunning = false
                updateNotification("SSH error: ${e.message?.take(50)}")
                stopSelf()
            }
        }.start()
    }

    private fun stopSshd() {
        sshdProcess?.let {
            it.destroyForcibly()
            sshdProcess = null
        }
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "OpenClaw::SshWakeLock"
        )
        wakeLock?.acquire(24 * 60 * 60 * 1000L)
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OpenClaw SSH",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the SSH server running in the background"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder.setContentTitle("OpenClaw SSH")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)

        return builder.build()
    }

    private fun updateNotification(text: String) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Exception) {}
    }
}
