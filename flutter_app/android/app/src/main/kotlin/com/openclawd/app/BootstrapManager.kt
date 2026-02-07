package com.openclawd.app

import android.content.Context
import android.system.Os
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.zip.GZIPInputStream
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream

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

        // Pure Java extraction using Apache Commons Compress.
        // Two-phase approach:
        //   Phase 1: Extract directories, regular files, and hard links (as copies).
        //   Phase 2: Create all symlinks (deferred so directory structure exists first).
        // This handles tarball entry ordering issues (e.g., bin/bash before bin→usr/bin).
        val deferredSymlinks = mutableListOf<Pair<String, String>>() // target, path

        FileInputStream(tarPath).use { fis ->
            BufferedInputStream(fis, 256 * 1024).use { bis ->
                GZIPInputStream(bis).use { gis ->
                    TarArchiveInputStream(gis).use { tis ->
                        var entry: TarArchiveEntry? = tis.nextEntry
                        while (entry != null) {
                            val name = entry.name
                                .removePrefix("./")
                                .removePrefix("/")

                            if (name.isEmpty() || name.startsWith("dev/") || name == "dev") {
                                entry = tis.nextEntry
                                continue
                            }

                            val outFile = File(rootfsDir, name)

                            when {
                                entry.isDirectory -> {
                                    outFile.mkdirs()
                                }
                                entry.isSymbolicLink -> {
                                    // Defer symlinks to phase 2
                                    deferredSymlinks.add(
                                        Pair(entry.linkName, outFile.absolutePath)
                                    )
                                }
                                entry.isLink -> {
                                    // Hard link → copy the target file
                                    // (symlinks break inside proot due to path translation)
                                    val target = entry.linkName
                                        .removePrefix("./")
                                        .removePrefix("/")
                                    val targetFile = File(rootfsDir, target)
                                    outFile.parentFile?.mkdirs()
                                    try {
                                        if (targetFile.exists()) {
                                            targetFile.copyTo(outFile, overwrite = true)
                                            if (targetFile.canExecute()) {
                                                outFile.setExecutable(true, false)
                                            }
                                        }
                                    } catch (_: Exception) {}
                                }
                                else -> {
                                    // Regular file
                                    outFile.parentFile?.mkdirs()
                                    FileOutputStream(outFile).use { fos ->
                                        val buf = ByteArray(65536)
                                        var len: Int
                                        while (tis.read(buf).also { len = it } != -1) {
                                            fos.write(buf, 0, len)
                                        }
                                    }
                                    // Preserve permissions
                                    if (entry.mode and 0b001_001_001 != 0) {
                                        outFile.setExecutable(true, false)
                                    }
                                    if (entry.mode and 0b010_010_010 != 0) {
                                        outFile.setWritable(true, false)
                                    }
                                    if (entry.mode and 0b100_100_100 != 0) {
                                        outFile.setReadable(true, false)
                                    }
                                }
                            }

                            entry = tis.nextEntry
                        }
                    }
                }
            }
        }

        // Phase 2: Create all symlinks now that the directory structure exists.
        // If a directory was created where a symlink should be (due to entry ordering),
        // we delete the directory first. This handles Ubuntu's merged /usr layout
        // where /bin → usr/bin, /sbin → usr/sbin, /lib → usr/lib.
        for ((target, path) in deferredSymlinks) {
            try {
                val file = File(path)
                if (file.exists()) {
                    if (file.isDirectory) {
                        // Directory exists where symlink should be — move contents
                        // to the real target directory, then replace with symlink.
                        // This handles /bin (dir with files) → usr/bin (symlink).
                        val linkTarget = if (target.startsWith("/")) {
                            target.removePrefix("/")
                        } else {
                            // Resolve relative target against parent dir
                            val parent = file.parentFile?.absolutePath ?: rootfsDir
                            File(parent, target).relativeTo(File(rootfsDir)).path
                        }
                        val realTargetDir = File(rootfsDir, linkTarget)
                        if (realTargetDir.exists() && realTargetDir.isDirectory) {
                            // Move files from this dir to the real target dir
                            file.listFiles()?.forEach { child ->
                                val dest = File(realTargetDir, child.name)
                                if (!dest.exists()) {
                                    child.renameTo(dest)
                                }
                            }
                        }
                        deleteRecursively(file)
                    } else {
                        file.delete()
                    }
                }
                file.parentFile?.mkdirs()
                Os.symlink(target, path)
            } catch (_: Exception) {}
        }

        // Verify extraction
        if (!File("$rootfsDir/bin/bash").exists() &&
            !File("$rootfsDir/usr/bin/bash").exists()) {
            throw RuntimeException("Extraction failed: bash not found in rootfs")
        }

        // Post-extraction: configure rootfs for proot compatibility
        configureRootfs()

        // Clean up tarball
        File(tarPath).delete()
    }

    /**
     * Write configuration files that make the rootfs work correctly under proot.
     * Called automatically after extraction.
     */
    private fun configureRootfs() {
        // 1. Disable apt sandboxing — proot fakes UID 0 via ptrace but cannot
        //    intercept setresuid/setresgid, so apt's _apt user privilege drop
        //    fails with "Operation not permitted". Tell apt to stay as root.
        val aptConfDir = File("$rootfsDir/etc/apt/apt.conf.d")
        aptConfDir.mkdirs()
        File(aptConfDir, "01-openclawd-proot").writeText(
            "APT::Sandbox::User \"root\";\n"
        )

        // 2. Ensure /etc/machine-id exists (dpkg triggers and systemd utils need it)
        val machineId = File("$rootfsDir/etc/machine-id")
        if (!machineId.exists()) {
            machineId.parentFile?.mkdirs()
            machineId.writeText("10000000000000000000000000000000\n")
        }

        // 3. Ensure policy-rc.d prevents services from auto-starting during install
        //    (they'd fail inside proot anyway)
        val policyRc = File("$rootfsDir/usr/sbin/policy-rc.d")
        policyRc.parentFile?.mkdirs()
        policyRc.writeText("#!/bin/sh\nexit 101\n")
        policyRc.setExecutable(true, false)
    }

    private fun deleteRecursively(file: File) {
        if (file.isDirectory) {
            file.listFiles()?.forEach { deleteRecursively(it) }
        }
        file.delete()
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
