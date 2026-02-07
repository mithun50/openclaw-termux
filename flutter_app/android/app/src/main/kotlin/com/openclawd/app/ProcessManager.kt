package com.openclawd.app

import java.io.BufferedReader
import java.io.InputStreamReader

class ProcessManager(
    private val filesDir: String,
    private val nativeLibDir: String
) {
    private val rootfsDir get() = "$filesDir/rootfs/ubuntu"
    private val tmpDir get() = "$filesDir/tmp"
    private val homeDir get() = "$filesDir/home"
    private val configDir get() = "$filesDir/config"

    fun getProotPath(): String {
        return "$nativeLibDir/libproot.so"
    }

    fun buildProotCommand(command: String): List<String> {
        val prootPath = getProotPath()
        val nodeOptions = "--require /root/.openclawd/bionic-bypass.js"

        val procFakes = "$configDir/proc_fakes"
        val sysFakes = "$configDir/sys_fakes"

        // Bind mounts match proot-distro's setup_fake_sysdata approach:
        // Android restricts many /proc and /sys entries, so we provide
        // static fake files to prevent crashes (e.g. libgcrypt SIGABRT).
        return listOf(
            prootPath,
            "-0",
            "--link2symlink",
            "--kernel-release=6.2.1-PRoot-Distro",
            "-r", rootfsDir,
            "-b", "/dev",
            "-b", "/proc",
            "-b", "/sys",
            // Fake proc entries (from proot-distro)
            "-b", "$procFakes/loadavg:/proc/loadavg",
            "-b", "$procFakes/stat:/proc/stat",
            "-b", "$procFakes/uptime:/proc/uptime",
            "-b", "$procFakes/version:/proc/version",
            "-b", "$procFakes/vmstat:/proc/vmstat",
            "-b", "$procFakes/cap_last_cap:/proc/sys/kernel/cap_last_cap",
            "-b", "$procFakes/max_user_watches:/proc/sys/fs/inotify/max_user_watches",
            "-b", "$procFakes/fips_enabled:/proc/sys/crypto/fips_enabled",
            // Fake sys entries
            "-b", "$sysFakes/empty:/sys/fs/selinux",
            // App binds
            "-b", "$configDir/resolv.conf:/etc/resolv.conf",
            "-b", "$homeDir:/root/home",
            "-w", "/root",
            "/bin/bash", "-c",
            "export NODE_OPTIONS=\"$nodeOptions\" && export HOME=/root && export DEBIAN_FRONTEND=noninteractive && export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin && $command"
        )
    }

    private val libDir get() = "$filesDir/lib"

    private fun prootEnv(): Map<String, String> = mapOf(
        "PROOT_TMP_DIR" to tmpDir,
        "PROOT_NO_SECCOMP" to "1",
        "PROOT_LOADER" to "$nativeLibDir/libprootloader.so",
        "PROOT_LOADER_32" to "$nativeLibDir/libprootloader32.so",
        "LD_LIBRARY_PATH" to "$libDir:$nativeLibDir",
        "HOME" to "/root"
    )

    fun runInProotSync(command: String, timeoutSeconds: Long = 900): String {
        val cmd = buildProotCommand(command)
        val env = prootEnv()

        val pb = ProcessBuilder(cmd)
        pb.environment().putAll(env)
        pb.redirectErrorStream(true)

        val process = pb.start()
        val output = StringBuilder()
        val reader = BufferedReader(InputStreamReader(process.inputStream))

        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val l = line ?: continue
            // Filter proot warnings
            if (!l.contains("proot warning") && !l.contains("can't sanitize")) {
                output.appendLine(l)
            }
        }

        val exited = process.waitFor(timeoutSeconds, java.util.concurrent.TimeUnit.SECONDS)
        if (!exited) {
            process.destroyForcibly()
            throw RuntimeException("Command timed out after ${timeoutSeconds}s")
        }

        val exitCode = process.exitValue()
        if (exitCode != 0) {
            throw RuntimeException(
                "Command failed (exit code $exitCode): ${output.toString().takeLast(2000)}"
            )
        }

        return output.toString()
    }

    fun startProotProcess(command: String): Process {
        val cmd = buildProotCommand(command)
        val env = prootEnv()

        val pb = ProcessBuilder(cmd)
        pb.environment().putAll(env)
        pb.redirectErrorStream(false)

        return pb.start()
    }
}
