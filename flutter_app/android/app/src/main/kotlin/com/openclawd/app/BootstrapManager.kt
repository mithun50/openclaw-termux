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

    fun setupDirectories() {
        listOf(rootfsDir, tmpDir, homeDir, configDir, "$homeDir/.openclawd").forEach {
            File(it).mkdirs()
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

        // Android's filesystem doesn't support hard links in app storage.
        // tar will report errors for hard links (e.g. perl5.38.2 -> perl)
        // but the actual files are still extracted. We collect stderr and
        // only fail if /bin/bash wasn't extracted (real failure).
        val process = ProcessBuilder(
            "tar", "xzf", tarPath, "-C", rootfsDir,
            "--no-same-owner", "--no-same-permissions"
        ).redirectErrorStream(true).start()

        val output = process.inputStream.bufferedReader().readText()
        process.waitFor()

        // Fix hard links that failed: create symlinks instead
        fixFailedHardLinks(output)

        // Verify extraction actually worked (bin/bash must exist)
        if (!File("$rootfsDir/bin/bash").exists()) {
            throw RuntimeException("Rootfs extraction failed: /bin/bash not found. tar output: $output")
        }

        // Clean up tarball
        File(tarPath).delete()
    }

    private fun fixFailedHardLinks(tarOutput: String) {
        // Parse "tar: can't link 'X' -> 'Y': Permission denied" and create symlinks
        val linkPattern = Regex("""can't link '([^']+)' -> '([^']+)'""")
        for (match in linkPattern.findAll(tarOutput)) {
            val source = match.groupValues[1]  // the new link that failed
            val target = match.groupValues[2]  // the existing file
            val sourceFile = File("$rootfsDir/$source")
            val targetFile = File("$rootfsDir/$target")

            if (targetFile.exists() && !sourceFile.exists()) {
                try {
                    // Create parent dirs if needed
                    sourceFile.parentFile?.mkdirs()
                    // Copy the file since symlinks may also not work
                    targetFile.copyTo(sourceFile, overwrite = true)
                } catch (_: Exception) {
                    // Best effort — non-critical files like perl aliases
                }
            }
        }
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
