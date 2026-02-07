package com.openclawd.app

import android.content.Context
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class BootstrapManager(
    private val context: Context,
    private val filesDir: String,
    private val nativeLibDir: String
) {
    private val rootfsDir get() = "$filesDir/rootfs/ubuntu"
    private val tmpDir get() = "$filesDir/tmp"
    private val homeDir get() = "$filesDir/home"
    private val configDir get() = "$filesDir/config"
    private val libDir get() = "$filesDir/lib"

    fun setupDirectories() {
        listOf(rootfsDir, tmpDir, homeDir, configDir, "$homeDir/.openclawd", libDir).forEach {
            File(it).mkdirs()
        }
        // Termux's proot links against libtalloc.so.2 but Android extracts it
        // as libtalloc.so (jniLibs naming convention). Create a copy with the
        // correct SONAME so the dynamic linker finds it.
        setupLibtalloc()
    }

    private fun setupLibtalloc() {
        val source = File("$nativeLibDir/libtalloc.so")
        val target = File("$libDir/libtalloc.so.2")
        if (source.exists() && !target.exists()) {
            source.copyTo(target)
            target.setExecutable(true)
        }
    }

    fun isBootstrapComplete(): Boolean {
        val rootfs = File(rootfsDir)
        val binBash = File("$rootfsDir/bin/bash")
        val bypass = File("$rootfsDir/root/.openclawd/bionic-bypass.js")
        return rootfs.exists() && binBash.exists() && bypass.exists()
    }

    fun getBootstrapStatus(): Map<String, Any> {
        val rootfsExists = File(rootfsDir).exists()
        val binBashExists = File("$rootfsDir/bin/bash").exists()
        val nodeExists = checkNodeInProot()
        val openclawExists = checkOpenClawInProot()
        val bypassExists = File("$rootfsDir/root/.openclawd/bionic-bypass.js").exists()

        return mapOf(
            "rootfsExists" to rootfsExists,
            "binBashExists" to binBashExists,
            "nodeInstalled" to nodeExists,
            "openclawInstalled" to openclawExists,
            "bypassInstalled" to bypassExists,
            "rootfsPath" to rootfsDir,
            "complete" to (rootfsExists && binBashExists && bypassExists)
        )
    }

    fun extractRootfs(tarPath: String) {
        val rootfs = File(rootfsDir)
        rootfs.mkdirs()

        // Use proot --link2symlink to wrap tar, exactly like proot-distro does.
        // proot intercepts syscalls so tar's hard links become symlinks and
        // absolute symlink targets are handled correctly.
        // No -r flag needed — proot just wraps the host tar binary.
        val prootPath = "$nativeLibDir/libproot.so"

        val pb = ProcessBuilder(
            prootPath,
            "--link2symlink",
            "tar", "-C", rootfsDir,
            "--warning=no-unknown-keyword",
            "--delay-directory-restore",
            "--preserve-permissions",
            "--no-same-owner",
            "-xzf", tarPath,
            "--exclude=dev"
        )
        pb.environment()["PROOT_TMP_DIR"] = tmpDir
        pb.environment()["PROOT_NO_SECCOMP"] = "1"
        pb.environment()["PROOT_LOADER"] = "$nativeLibDir/libprootloader.so"
        pb.environment()["PROOT_LOADER_32"] = "$nativeLibDir/libprootloader32.so"
        pb.environment()["LD_LIBRARY_PATH"] = "$libDir:$nativeLibDir"
        pb.redirectErrorStream(true)

        val process = pb.start()
        val output = process.inputStream.bufferedReader().readText()
        val exitCode = process.waitFor()

        // Verify extraction worked
        if (!File("$rootfsDir/bin/bash").exists()) {
            throw RuntimeException(
                "Rootfs extraction failed (code $exitCode): /bin/bash not found. Output: $output"
            )
        }

        // Clean up tarball
        File(tarPath).delete()
    }

    fun installBionicBypass() {
        val bypassDir = File("$rootfsDir/root/.openclawd")
        bypassDir.mkdirs()

        val bypassContent = """
// OpenClawd Bionic Bypass - Auto-generated
const os = require('os');
const originalNetworkInterfaces = os.networkInterfaces;

os.networkInterfaces = function() {
  try {
    const interfaces = originalNetworkInterfaces.call(os);
    if (interfaces && Object.keys(interfaces).length > 0) {
      return interfaces;
    }
  } catch (e) {
    // Bionic blocked the call, use fallback
  }

  // Return mock loopback interface
  return {
    lo: [
      {
        address: '127.0.0.1',
        netmask: '255.0.0.0',
        family: 'IPv4',
        mac: '00:00:00:00:00:00',
        internal: true,
        cidr: '127.0.0.1/8'
      }
    ]
  };
};
""".trimIndent()

        File("$rootfsDir/root/.openclawd/bionic-bypass.js").writeText(bypassContent)

        // Patch .bashrc
        val bashrc = File("$rootfsDir/root/.bashrc")
        val exportLine = "export NODE_OPTIONS=\"--require /root/.openclawd/bionic-bypass.js\""

        val existing = if (bashrc.exists()) bashrc.readText() else ""
        if (!existing.contains("bionic-bypass")) {
            bashrc.appendText("\n# OpenClawd Bionic Bypass\n$exportLine\n")
        }
    }

    fun writeResolvConf() {
        val configDir = File(this.configDir)
        configDir.mkdirs()

        File("$configDir/resolv.conf").writeText("nameserver 8.8.8.8\nnameserver 8.8.4.4\n")
    }

    private fun checkNodeInProot(): Boolean {
        return try {
            val pm = ProcessManager(filesDir, nativeLibDir)
            val output = pm.runInProotSync("node --version")
            output.trim().startsWith("v")
        } catch (e: Exception) {
            false
        }
    }

    private fun checkOpenClawInProot(): Boolean {
        return try {
            val pm = ProcessManager(filesDir, nativeLibDir)
            val output = pm.runInProotSync("command -v openclaw")
            output.trim().isNotEmpty()
        } catch (e: Exception) {
            false
        }
    }
}
