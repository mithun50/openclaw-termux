package com.nxg.openclawproot

import android.content.Context
import android.system.Os
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.util.zip.GZIPInputStream
import org.apache.commons.compress.archivers.ar.ArArchiveInputStream
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.compressors.xz.XZCompressorInputStream
import org.apache.commons.compress.compressors.zstandard.ZstdCompressorInputStream

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
        listOf(rootfsDir, tmpDir, homeDir, configDir, "$homeDir/.openclaw", libDir).forEach {
            File(it).mkdirs()
        }
        // Termux's proot links against libtalloc.so.2 but Android extracts it
        // as libtalloc.so (jniLibs naming convention). Create a copy with the
        // correct SONAME so the dynamic linker finds it.
        setupLibtalloc()
        // Create fake /proc and /sys files for proot bind mounts
        setupFakeSysdata()
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
        val bypass = File("$rootfsDir/root/.openclaw/bionic-bypass.js")
        val node = File("$rootfsDir/usr/local/bin/node")
        val openclaw = File("$rootfsDir/usr/local/lib/node_modules/openclaw/package.json")
        return rootfs.exists() && binBash.exists() && bypass.exists()
            && node.exists() && openclaw.exists()
    }

    fun getBootstrapStatus(): Map<String, Any> {
        val rootfsExists = File(rootfsDir).exists()
        val binBashExists = File("$rootfsDir/bin/bash").exists()
        val nodeExists = File("$rootfsDir/usr/local/bin/node").exists()
        val openclawExists = File("$rootfsDir/usr/local/lib/node_modules/openclaw/package.json").exists()
        val bypassExists = File("$rootfsDir/root/.openclaw/bionic-bypass.js").exists()

        return mapOf(
            "rootfsExists" to rootfsExists,
            "binBashExists" to binBashExists,
            "nodeInstalled" to nodeExists,
            "openclawInstalled" to openclawExists,
            "bypassInstalled" to bypassExists,
            "rootfsPath" to rootfsDir,
            "complete" to (rootfsExists && binBashExists && bypassExists
                && nodeExists && openclawExists)
        )
    }

    fun extractRootfs(tarPath: String) {
        val rootfs = File(rootfsDir)
        // Clean up any previous failed extraction
        if (rootfs.exists()) {
            deleteRecursively(rootfs)
        }
        rootfs.mkdirs()

        // Pure Java extraction using Apache Commons Compress.
        // Two-phase approach:
        //   Phase 1: Extract directories, regular files, and hard links (as copies).
        //   Phase 2: Create all symlinks (deferred so directory structure exists first).
        // This handles tarball entry ordering issues (e.g., bin/bash before bin→usr/bin).
        val deferredSymlinks = mutableListOf<Pair<String, String>>() // target, path
        var entryCount = 0
        var fileCount = 0
        var symlinkCount = 0
        var extractionError: Exception? = null

        try {
            FileInputStream(tarPath).use { fis ->
                BufferedInputStream(fis, 256 * 1024).use { bis ->
                    GZIPInputStream(bis).use { gis ->
                        TarArchiveInputStream(gis).use { tis ->
                            var entry: TarArchiveEntry? = tis.nextEntry
                            while (entry != null) {
                                entryCount++
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
                                        symlinkCount++
                                    }
                                    entry.isLink -> {
                                        // Hard link → copy the target file
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
                                                fileCount++
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
                                        outFile.setReadable(true, false)
                                        outFile.setWritable(true, false)
                                        val mode = entry.mode
                                        if (mode == 0 || mode and 0b001_001_001 != 0) {
                                            val path = name.lowercase()
                                            if (mode and 0b001_001_001 != 0 ||
                                                path.contains("/bin/") ||
                                                path.contains("/sbin/") ||
                                                path.endsWith(".sh") ||
                                                path.contains("/lib/apt/methods/")) {
                                                outFile.setExecutable(true, false)
                                            }
                                        }
                                        fileCount++
                                    }
                                }

                                entry = tis.nextEntry
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            extractionError = e
        }

        if (entryCount == 0) {
            throw RuntimeException(
                "Extraction failed: tarball appears empty or corrupt. " +
                "Error: ${extractionError?.message ?: "none"}"
            )
        }

        if (extractionError != null && fileCount < 100) {
            throw RuntimeException(
                "Extraction failed after $entryCount entries ($fileCount files): " +
                "${extractionError!!.message}"
            )
        }

        // Phase 2: Create all symlinks now that the directory structure exists.
        var symlinkErrors = 0
        var lastSymlinkError = ""
        for ((target, path) in deferredSymlinks) {
            try {
                val file = File(path)
                if (file.exists()) {
                    if (file.isDirectory) {
                        val linkTarget = if (target.startsWith("/")) {
                            target.removePrefix("/")
                        } else {
                            val parent = file.parentFile?.absolutePath ?: rootfsDir
                            File(parent, target).relativeTo(File(rootfsDir)).path
                        }
                        val realTargetDir = File(rootfsDir, linkTarget)
                        if (realTargetDir.exists() && realTargetDir.isDirectory) {
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
            } catch (e: Exception) {
                symlinkErrors++
                lastSymlinkError = "$path -> $target: ${e.message}"
            }
        }

        // Verify extraction
        if (!File("$rootfsDir/bin/bash").exists() &&
            !File("$rootfsDir/usr/bin/bash").exists()) {
            throw RuntimeException(
                "Extraction failed: bash not found in rootfs. " +
                "Processed $entryCount entries, $fileCount files, " +
                "$symlinkCount symlinks (${symlinkErrors} symlink errors). " +
                "Last symlink error: $lastSymlinkError. " +
                "usr/bin exists: ${File("$rootfsDir/usr/bin").exists()}. " +
                "Extraction error: ${extractionError?.message ?: "none"}"
            )
        }

        // Post-extraction: configure rootfs for proot compatibility
        configureRootfs()

        // Clean up tarball
        File(tarPath).delete()
    }

    /**
     * Extract all .deb packages from the apt cache into the rootfs.
     * Uses Java (Apache Commons Compress) to avoid fork+exec issues in proot.
     * A .deb is an ar archive containing data.tar.{xz,gz,zst}.
     * Returns the number of packages extracted.
     */
    fun extractDebPackages(): Int {
        val archivesDir = File("$rootfsDir/var/cache/apt/archives")
        if (!archivesDir.exists()) {
            throw RuntimeException("No apt archives directory found")
        }

        val debFiles = archivesDir.listFiles { f -> f.name.endsWith(".deb") }
            ?: throw RuntimeException("No .deb files found in apt cache")

        if (debFiles.isEmpty()) {
            throw RuntimeException("No .deb files found in apt cache")
        }

        var extracted = 0
        val errors = mutableListOf<String>()

        for (debFile in debFiles) {
            try {
                extractSingleDeb(debFile)
                extracted++
            } catch (e: Exception) {
                errors.add("${debFile.name}: ${e.message}")
            }
        }

        if (extracted == 0) {
            throw RuntimeException(
                "Failed to extract any .deb packages. Errors: ${errors.joinToString("; ")}"
            )
        }

        // Fix permissions on newly extracted binaries
        fixBinPermissions()

        return extracted
    }

    /**
     * Extract a single .deb file into the rootfs.
     * Reads the ar archive, finds data.tar.*, decompresses, and extracts.
     */
    private fun extractSingleDeb(debFile: File) {
        FileInputStream(debFile).use { fis ->
            BufferedInputStream(fis).use { bis ->
                ArArchiveInputStream(bis).use { arIn ->
                    var arEntry = arIn.nextEntry
                    while (arEntry != null) {
                        val name = arEntry.name
                        if (name.startsWith("data.tar")) {
                            // Wrap in appropriate decompressor
                            val dataStream: InputStream = when {
                                name.endsWith(".xz") -> XZCompressorInputStream(arIn)
                                name.endsWith(".gz") -> GZIPInputStream(arIn)
                                name.endsWith(".zst") -> ZstdCompressorInputStream(arIn)
                                else -> arIn // plain .tar or unknown
                            }

                            // Extract data.tar contents into rootfs
                            TarArchiveInputStream(dataStream).use { tarIn ->
                                var tarEntry = tarIn.nextEntry
                                while (tarEntry != null) {
                                    val entryName = tarEntry.name
                                        .removePrefix("./")
                                        .removePrefix("/")

                                    if (entryName.isEmpty()) {
                                        tarEntry = tarIn.nextEntry
                                        continue
                                    }

                                    val outFile = File(rootfsDir, entryName)

                                    when {
                                        tarEntry.isDirectory -> {
                                            outFile.mkdirs()
                                        }
                                        tarEntry.isSymbolicLink -> {
                                            try {
                                                if (outFile.exists()) outFile.delete()
                                                outFile.parentFile?.mkdirs()
                                                Os.symlink(tarEntry.linkName, outFile.absolutePath)
                                            } catch (_: Exception) {}
                                        }
                                        tarEntry.isLink -> {
                                            val target = tarEntry.linkName
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
                                            outFile.parentFile?.mkdirs()
                                            FileOutputStream(outFile).use { fos ->
                                                val buf = ByteArray(65536)
                                                var len: Int
                                                while (tarIn.read(buf).also { len = it } != -1) {
                                                    fos.write(buf, 0, len)
                                                }
                                            }
                                            outFile.setReadable(true, false)
                                            outFile.setWritable(true, false)
                                            val mode = tarEntry.mode
                                            if (mode and 0b001_001_001 != 0) {
                                                outFile.setExecutable(true, false)
                                            }
                                            // Ensure bin/sbin files are executable
                                            val path = entryName.lowercase()
                                            if (path.contains("/bin/") ||
                                                path.contains("/sbin/")) {
                                                outFile.setExecutable(true, false)
                                            }
                                        }
                                    }

                                    tarEntry = tarIn.nextEntry
                                }
                            }
                            return // Found and processed data.tar, done
                        }
                        arEntry = arIn.nextEntry
                    }
                }
            }
        }
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
        File(aptConfDir, "01-openclaw-proot").writeText(
            "APT::Sandbox::User \"root\";\n" +
            // Disable PTY allocation when APT forks dpkg. APT's child process
            // calls SetupSlavePtyMagic() before execvp(dpkg); in proot on
            // Android 10+ (W^X policy), the PTY/chdir setup in the child can
            // fail causing _exit(100). Disabling this simplifies the fork path.
            "Dpkg::Use-Pty \"0\";\n" +
            // Pass dpkg options through apt to tolerate proot failures
            "Dpkg::Options { \"--force-confnew\"; \"--force-overwrite\"; };\n"
        )

        // 2. Configure dpkg for proot compatibility
        //    - force-unsafe-io: skip fsync/sync_file_range (may ENOSYS in proot)
        //    - no-debsig: skip signature verification
        val dpkgConfDir = File("$rootfsDir/etc/dpkg/dpkg.cfg.d")
        dpkgConfDir.mkdirs()
        File(dpkgConfDir, "01-openclaw-proot").writeText(
            "force-unsafe-io\n" +
            "no-debsig\n" +
            "force-overwrite\n" +
            "force-depends\n"
        )

        // 3. Ensure essential directories exist
        // mkdir syscall is broken inside proot on Android 10+.
        // Pre-create ALL directories that tools need at runtime.
        listOf(
            "$rootfsDir/etc/ssl/certs",
            "$rootfsDir/usr/share/keyrings",
            "$rootfsDir/etc/apt/sources.list.d",
            "$rootfsDir/var/lib/dpkg/updates",
            "$rootfsDir/var/lib/dpkg/triggers",
            // npm cache directories (npm can't mkdir inside proot)
            "$rootfsDir/tmp/npm-cache/_cacache/tmp",
            "$rootfsDir/tmp/npm-cache/_cacache/content-v2",
            "$rootfsDir/tmp/npm-cache/_cacache/index-v5",
            "$rootfsDir/tmp/npm-cache/_logs",
            // Node.js / npm working directories
            "$rootfsDir/root/.npm",
            "$rootfsDir/root/.config",
            "$rootfsDir/usr/local/lib/node_modules",
            "$rootfsDir/usr/local/bin",
            // OpenClaw runtime directories (can't mkdir at runtime)
            "$rootfsDir/root/.openclaw",
            "$rootfsDir/root/.openclaw/data",
            "$rootfsDir/root/.openclaw/memory",
            "$rootfsDir/root/.openclaw/skills",
            "$rootfsDir/root/.openclaw/config",
            "$rootfsDir/root/.openclaw/extensions",
            "$rootfsDir/root/.openclaw/logs",
            "$rootfsDir/root/.config/openclaw",
            "$rootfsDir/root/.local/share",
            "$rootfsDir/root/.cache",
            "$rootfsDir/root/.cache/openclaw",
            "$rootfsDir/root/.cache/node",
            // General runtime directories
            "$rootfsDir/var/tmp",
            "$rootfsDir/run",
            "$rootfsDir/run/lock",
            "$rootfsDir/dev/shm",
        ).forEach { File(it).mkdirs() }

        // 4. Ensure /etc/machine-id exists (dpkg triggers and systemd utils need it)
        val machineId = File("$rootfsDir/etc/machine-id")
        if (!machineId.exists()) {
            machineId.parentFile?.mkdirs()
            machineId.writeText("10000000000000000000000000000000\n")
        }

        // 4. Ensure policy-rc.d prevents services from auto-starting during install
        //    (they'd fail inside proot anyway)
        val policyRc = File("$rootfsDir/usr/sbin/policy-rc.d")
        policyRc.parentFile?.mkdirs()
        policyRc.writeText("#!/bin/sh\nexit 101\n")
        policyRc.setExecutable(true, false)

        // 5. Register Android user/groups in rootfs (matching proot-distro).
        //    dpkg and apt need valid user/group databases.
        registerAndroidUsers()

        // 6. Write /etc/hosts (some post-install scripts need hostname resolution)
        val hosts = File("$rootfsDir/etc/hosts")
        if (!hosts.exists() || !hosts.readText().contains("localhost")) {
            hosts.writeText(
                "127.0.0.1   localhost.localdomain localhost\n" +
                "::1         localhost.localdomain localhost ip6-localhost ip6-loopback\n"
            )
        }

        // 7. Ensure /tmp exists with world-writable + sticky permissions
        //    (needed for /dev/shm bind mount and general temp file usage)
        val tmpDir = File("$rootfsDir/tmp")
        tmpDir.mkdirs()
        tmpDir.setReadable(true, false)
        tmpDir.setWritable(true, false)
        tmpDir.setExecutable(true, false)

        // 8. Fix executable permissions on critical directories.
        //    Our Java extraction might not preserve all permission bits correctly
        //    (dpkg error 100 = "Could not exec dpkg" = permission issue).
        //    Recursively ensure all files in bin/sbin/lib dirs are executable.
        fixBinPermissions()
    }

    /**
     * Ensure all files in executable directories have the execute bit set.
     * Java's File API doesn't support full Unix permissions, so tar extraction
     * may leave some binaries without +x, causing "Could not exec dpkg" (error 100).
     */
    private fun fixBinPermissions() {
        // Directories whose files (recursively) must be executable
        val recursiveExecDirs = listOf(
            "$rootfsDir/usr/bin",
            "$rootfsDir/usr/sbin",
            "$rootfsDir/usr/local/bin",
            "$rootfsDir/usr/local/sbin",
            "$rootfsDir/usr/lib/apt/methods",
            "$rootfsDir/usr/lib/dpkg",
            "$rootfsDir/usr/lib/git-core",     // git sub-commands (git-remote-https, etc.)
            "$rootfsDir/usr/libexec",
            "$rootfsDir/var/lib/dpkg/info",    // dpkg maintainer scripts (preinst/postinst/prerm/postrm)
            "$rootfsDir/usr/share/debconf",    // debconf frontend scripts
            // These might be symlinks to usr/* in merged /usr, but
            // if they're real dirs we need to fix them too
            "$rootfsDir/bin",
            "$rootfsDir/sbin",
        )
        for (dirPath in recursiveExecDirs) {
            val dir = File(dirPath)
            if (dir.exists() && dir.isDirectory) {
                fixExecRecursive(dir)
            }
        }
        // Also fix shared libraries (dpkg, apt, etc. link against them)
        val libDirs = listOf(
            "$rootfsDir/usr/lib",
            "$rootfsDir/lib",
        )
        for (dirPath in libDirs) {
            val dir = File(dirPath)
            if (dir.exists() && dir.isDirectory) {
                fixSharedLibsRecursive(dir)
            }
        }
    }

    /** Recursively set +rx on all regular files in a directory tree. */
    private fun fixExecRecursive(dir: File) {
        dir.listFiles()?.forEach { file ->
            if (file.isDirectory) {
                fixExecRecursive(file)
            } else if (file.isFile) {
                file.setReadable(true, false)
                file.setExecutable(true, false)
            }
        }
    }

    private fun fixSharedLibsRecursive(dir: File) {
        dir.listFiles()?.forEach { file ->
            if (file.isDirectory) {
                fixSharedLibsRecursive(file)
            } else if (file.name.endsWith(".so") || file.name.contains(".so.")) {
                file.setReadable(true, false)
                file.setExecutable(true, false)
            }
        }
    }

    /**
     * Register Android UID/GID in the rootfs user databases,
     * matching what proot-distro does during installation.
     * This ensures dpkg/apt can resolve user/group names.
     */
    private fun registerAndroidUsers() {
        val uid = android.os.Process.myUid()
        val gid = uid // On Android, primary GID == UID

        // Ensure files are writable
        for (name in listOf("passwd", "shadow", "group", "gshadow")) {
            val f = File("$rootfsDir/etc/$name")
            if (f.exists()) f.setWritable(true, false)
        }

        // Add Android app user to /etc/passwd
        val passwd = File("$rootfsDir/etc/passwd")
        if (passwd.exists()) {
            val content = passwd.readText()
            if (!content.contains("aid_android")) {
                passwd.appendText("aid_android:x:$uid:$gid:Android:/:/sbin/nologin\n")
            }
        }

        // Add to /etc/shadow
        val shadow = File("$rootfsDir/etc/shadow")
        if (shadow.exists()) {
            val content = shadow.readText()
            if (!content.contains("aid_android")) {
                shadow.appendText("aid_android:*:18446:0:99999:7:::\n")
            }
        }

        // Add Android groups to /etc/group
        val group = File("$rootfsDir/etc/group")
        if (group.exists()) {
            val content = group.readText()
            // Add common Android groups that packages might reference
            val groups = mapOf(
                "aid_inet" to 3003,       // Internet access
                "aid_net_raw" to 3004,    // Raw sockets
                "aid_sdcard_rw" to 1015,  // SD card write
                "aid_android" to gid,     // App's own group
            )
            for ((name, id) in groups) {
                if (!content.contains(name)) {
                    group.appendText("$name:x:$id:root,aid_android\n")
                }
            }
        }

        // Add to /etc/gshadow
        val gshadow = File("$rootfsDir/etc/gshadow")
        if (gshadow.exists()) {
            val content = gshadow.readText()
            val groups = listOf("aid_inet", "aid_net_raw", "aid_sdcard_rw", "aid_android")
            for (name in groups) {
                if (!content.contains(name)) {
                    gshadow.appendText("$name:*::root,aid_android\n")
                }
            }
        }
    }

    /**
     * Extract a Node.js binary tarball (.tar.xz) into the rootfs.
     * The tarball contains node-v22.x.x-linux-arm64/ with bin/, lib/, etc.
     * We extract its contents into /usr/local/ so node and npm are on PATH.
     * This bypasses the NodeSource repo (curl/gpg fail in proot).
     */
    fun extractNodeTarball(tarPath: String) {
        val destDir = File("$rootfsDir/usr/local")
        destDir.mkdirs()

        var entryCount = 0
        try {
            FileInputStream(tarPath).use { fis ->
                BufferedInputStream(fis, 256 * 1024).use { bis ->
                    XZCompressorInputStream(bis).use { xzis ->
                        TarArchiveInputStream(xzis).use { tis ->
                            var entry: TarArchiveEntry? = tis.nextEntry
                            while (entry != null) {
                                entryCount++
                                val name = entry.name

                                // Strip the top-level directory (node-v22.x.x-linux-arm64/)
                                val slashIdx = name.indexOf('/')
                                if (slashIdx < 0 || slashIdx == name.length - 1) {
                                    entry = tis.nextEntry
                                    continue
                                }
                                val relPath = name.substring(slashIdx + 1)
                                if (relPath.isEmpty()) {
                                    entry = tis.nextEntry
                                    continue
                                }

                                val outFile = File(destDir, relPath)

                                when {
                                    entry.isDirectory -> {
                                        outFile.mkdirs()
                                    }
                                    entry.isSymbolicLink -> {
                                        try {
                                            if (outFile.exists()) outFile.delete()
                                            outFile.parentFile?.mkdirs()
                                            Os.symlink(entry.linkName, outFile.absolutePath)
                                        } catch (_: Exception) {}
                                    }
                                    else -> {
                                        outFile.parentFile?.mkdirs()
                                        FileOutputStream(outFile).use { fos ->
                                            val buf = ByteArray(65536)
                                            var len: Int
                                            while (tis.read(buf).also { len = it } != -1) {
                                                fos.write(buf, 0, len)
                                            }
                                        }
                                        outFile.setReadable(true, false)
                                        outFile.setWritable(true, false)
                                        // Set executable for bin/ files and .so files
                                        val mode = entry.mode
                                        if (mode and 0b001_001_001 != 0 ||
                                            relPath.startsWith("bin/") ||
                                            relPath.contains(".so")) {
                                            outFile.setExecutable(true, false)
                                        }
                                    }
                                }

                                entry = tis.nextEntry
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            throw RuntimeException(
                "Node.js tarball extraction failed after $entryCount entries: ${e.message}"
            )
        }

        // Verify node binary exists
        val nodeBin = File("$rootfsDir/usr/local/bin/node")
        if (!nodeBin.exists()) {
            throw RuntimeException(
                "Node.js extraction failed: node binary not found at /usr/local/bin/node " +
                "(processed $entryCount entries)"
            )
        }
        nodeBin.setExecutable(true, false)

        // Clean up tarball
        File(tarPath).delete()
    }

    /**
     * Create shell wrapper scripts in /usr/local/bin/ for a globally-installed
     * npm package. npm's `install -g` creates symlinks, but symlinks can fail
     * silently in proot. Shell wrappers are a reliable fallback.
     *
     * Reads the package.json `bin` field directly from the rootfs filesystem
     * (no shell escaping needed).
     */
    fun createBinWrappers(packageName: String) {
        val pkgDir = File("$rootfsDir/usr/local/lib/node_modules/$packageName")
        val pkgJson = File(pkgDir, "package.json")
        if (!pkgJson.exists()) {
            throw RuntimeException("Package not found: $pkgDir")
        }

        // Simple JSON parsing for the "bin" field
        val json = pkgJson.readText()
        val binDir = File("$rootfsDir/usr/local/bin")
        binDir.mkdirs()

        // Parse bin entries from package.json
        // "bin": "cli.js"  OR  "bin": {"openclaw": "bin/openclaw.js", ...}
        val binEntries = mutableMapOf<String, String>()

        val binMatch = Regex(""""bin"\s*:\s*(\{[^}]*\}|"[^"]*")""").find(json)
        if (binMatch != null) {
            val value = binMatch.groupValues[1]
            if (value.startsWith("{")) {
                // Object: {"name": "path", ...}
                Regex(""""([^"]+)"\s*:\s*"([^"]+)"""").findAll(value).forEach {
                    binEntries[it.groupValues[1]] = it.groupValues[2]
                }
            } else {
                // String: "path" — use package name as bin name
                val path = value.trim('"')
                binEntries[packageName] = path
            }
        }

        if (binEntries.isEmpty()) {
            // Fallback: check for common entry points
            for (candidate in listOf("bin/$packageName.js", "bin/$packageName", "cli.js", "index.js")) {
                if (File(pkgDir, candidate).exists()) {
                    binEntries[packageName] = candidate
                    break
                }
            }
        }

        for ((name, relPath) in binEntries) {
            val binFile = File(binDir, name)
            // Only create wrapper if the symlink doesn't already work
            if (binFile.exists() && binFile.canExecute()) continue

            val target = "/usr/local/lib/node_modules/$packageName/$relPath"
            val wrapper = "#!/bin/sh\nexec node \"$target\" \"\$@\"\n"
            binFile.writeText(wrapper)
            binFile.setExecutable(true, false)
            binFile.setReadable(true, false)
        }
    }

    private fun deleteRecursively(file: File) {
        if (file.isDirectory) {
            file.listFiles()?.forEach { deleteRecursively(it) }
        }
        file.delete()
    }

    fun installBionicBypass() {
        val bypassDir = File("$rootfsDir/root/.openclaw")
        bypassDir.mkdirs()

        // 1. CWD fix — proot's getcwd() syscall returns ENOSYS on Android 10+.
        //    process.cwd() is called by Node's CJS module resolver and npm.
        //    This MUST be loaded before any other module.
        val cwdFixContent = """
// OpenClaw CWD Fix - Auto-generated
// proot on Android 10+ returns ENOSYS for getcwd() syscall.
// Patch process.cwd to return /root on failure.
const _origCwd = process.cwd;
process.cwd = function() {
  try { return _origCwd.call(process); }
  catch(e) { return process.env.HOME || '/root'; }
};
""".trimIndent()
        File(bypassDir, "cwd-fix.js").writeText(cwdFixContent)

        // 2. Node wrapper — patches broken syscalls then runs the target script.
        //    Used during bootstrap (where NODE_OPTIONS must be unset).
        //    Usage: node /root/.openclaw/node-wrapper.js <script> [args...]
        val wrapperContent = """
// OpenClaw Node Wrapper - Auto-generated
// Patches broken proot syscalls, then loads the target script.
// Used for bootstrap-time npm operations.

// --- Load shared proot compatibility patches ---
require('/root/.openclaw/proot-compat.js');

// Load target script
const script = process.argv[2];
if (script) {
  process.argv = [process.argv[0], script, ...process.argv.slice(3)];
  require(script);
} else {
  console.log('Usage: node node-wrapper.js <script> [args...]');
  process.exit(1);
}
""".trimIndent()
        File(bypassDir, "node-wrapper.js").writeText(wrapperContent)

        // 3. Shared proot compatibility patches — used by both node-wrapper.js
        //    (bootstrap) and bionic-bypass.js (runtime).
        //    Patches: process.cwd, fs.mkdir, child_process.spawn, os.*, fs.rename,
        //    fs.watch, fs.chmod/chown.
        val prootCompatContent = """
// OpenClaw Proot Compatibility Layer - Auto-generated
// Patches all known broken syscalls in proot on Android 10+.
// This file is require()'d by both node-wrapper.js and bionic-bypass.js.

'use strict';

// ====================================================================
// 1. process.cwd() — getcwd() returns ENOSYS in proot
// ====================================================================
const _origCwd = process.cwd;
process.cwd = function() {
  try { return _origCwd.call(process); }
  catch(e) { return process.env.HOME || '/root'; }
};

// ====================================================================
// 2. os module patches — various /proc reads fail in proot
// ====================================================================
const _os = require('os');

// os.hostname() — may fail reading /proc/sys/kernel/hostname
const _origHostname = _os.hostname;
_os.hostname = function() {
  try { return _origHostname.call(_os); }
  catch(e) { return 'localhost'; }
};

// os.tmpdir() — ensure it returns /tmp
const _origTmpdir = _os.tmpdir;
_os.tmpdir = function() {
  try {
    const t = _origTmpdir.call(_os);
    return t || '/tmp';
  } catch(e) { return '/tmp'; }
};

// os.homedir() — may fail with ENOSYS
const _origHomedir = _os.homedir;
_os.homedir = function() {
  try { return _origHomedir.call(_os); }
  catch(e) { return process.env.HOME || '/root'; }
};

// os.userInfo() — getpwuid may fail in proot
const _origUserInfo = _os.userInfo;
_os.userInfo = function(opts) {
  try { return _origUserInfo.call(_os, opts); }
  catch(e) {
    return {
      uid: 0, gid: 0,
      username: 'root',
      homedir: process.env.HOME || '/root',
      shell: '/bin/bash'
    };
  }
};

// os.cpus() — reading /proc/cpuinfo may fail
const _origCpus = _os.cpus;
_os.cpus = function() {
  try {
    const cpus = _origCpus.call(_os);
    if (cpus && cpus.length > 0) return cpus;
  } catch(e) {}
  return [{ model: 'ARM', speed: 2000, times: { user: 0, nice: 0, sys: 0, idle: 0, irq: 0 } }];
};

// os.totalmem() / os.freemem() — reading /proc/meminfo may fail
const _origTotalmem = _os.totalmem;
_os.totalmem = function() {
  try { return _origTotalmem.call(_os); }
  catch(e) { return 4 * 1024 * 1024 * 1024; } // 4GB fallback
};
const _origFreemem = _os.freemem;
_os.freemem = function() {
  try { return _origFreemem.call(_os); }
  catch(e) { return 2 * 1024 * 1024 * 1024; } // 2GB fallback
};

// os.networkInterfaces() — Android blocks getifaddrs()
const _origNetIf = _os.networkInterfaces;
_os.networkInterfaces = function() {
  try {
    const ifaces = _origNetIf.call(_os);
    if (ifaces && Object.keys(ifaces).length > 0) return ifaces;
  } catch(e) {}
  return {
    lo: [{
      address: '127.0.0.1', netmask: '255.0.0.0', family: 'IPv4',
      mac: '00:00:00:00:00:00', internal: true, cidr: '127.0.0.1/8'
    }]
  };
};

// ====================================================================
// 3. fs.mkdir — mkdirat() returns ENOSYS in proot
// ====================================================================
const _fs = require('fs');
const _path = require('path');
const _origMkdirSync = _fs.mkdirSync;
_fs.mkdirSync = function(p, options) {
  try {
    return _origMkdirSync.call(_fs, p, options);
  } catch(e) {
    if (e.code === 'ENOSYS' || (e.code === 'ENOENT' && options && options.recursive)) {
      const parts = _path.resolve(String(p)).split(_path.sep).filter(Boolean);
      let current = '';
      for (const part of parts) {
        current += _path.sep + part;
        try { _origMkdirSync.call(_fs, current); }
        catch(e2) { if (e2.code !== 'EEXIST' && e2.code !== 'EISDIR') { /* skip */ } }
      }
      return undefined;
    }
    throw e;
  }
};
const _origMkdir = _fs.mkdir;
_fs.mkdir = function(p, options, cb) {
  if (typeof options === 'function') { cb = options; options = undefined; }
  try { _fs.mkdirSync(p, options); if (cb) cb(null); }
  catch(e) { if (cb) cb(e); else throw e; }
};
const _fsp = _fs.promises;
if (_fsp) {
  const _origMkdirP = _fsp.mkdir;
  _fsp.mkdir = async function(p, options) {
    try { return await _origMkdirP.call(_fsp, p, options); }
    catch(e) {
      if (e.code === 'ENOSYS' || (e.code === 'ENOENT' && options && options.recursive)) {
        _fs.mkdirSync(p, options); return undefined;
      }
      throw e;
    }
  };
}

// ====================================================================
// 4. fs.rename — renameat2() may ENOSYS in proot; fallback to copy+unlink
// ====================================================================
const _origRenameSync = _fs.renameSync;
_fs.renameSync = function(oldPath, newPath) {
  try { return _origRenameSync.call(_fs, oldPath, newPath); }
  catch(e) {
    if (e.code === 'ENOSYS' || e.code === 'EXDEV') {
      _fs.copyFileSync(oldPath, newPath);
      try { _fs.unlinkSync(oldPath); } catch(_) {}
      return;
    }
    throw e;
  }
};
const _origRename = _fs.rename;
_fs.rename = function(oldPath, newPath, cb) {
  _origRename.call(_fs, oldPath, newPath, function(err) {
    if (err && (err.code === 'ENOSYS' || err.code === 'EXDEV')) {
      try {
        _fs.copyFileSync(oldPath, newPath);
        try { _fs.unlinkSync(oldPath); } catch(_) {}
        if (cb) cb(null);
      } catch(e2) { if (cb) cb(e2); }
    } else { if (cb) cb(err); }
  });
};
if (_fsp) {
  const _origRenameP = _fsp.rename;
  _fsp.rename = async function(oldPath, newPath) {
    try { return await _origRenameP.call(_fsp, oldPath, newPath); }
    catch(e) {
      if (e.code === 'ENOSYS' || e.code === 'EXDEV') {
        await _fsp.copyFile(oldPath, newPath);
        try { await _fsp.unlink(oldPath); } catch(_) {}
        return;
      }
      throw e;
    }
  };
}

// ====================================================================
// 5. fs.chmod/chown — fchmodat/fchownat may fail; tolerate ENOSYS
// ====================================================================
for (const fn of ['chmod', 'chown', 'lchown']) {
  const origSync = _fs[fn + 'Sync'];
  if (origSync) {
    _fs[fn + 'Sync'] = function() {
      try { return origSync.apply(_fs, arguments); }
      catch(e) { if (e.code === 'ENOSYS') return; throw e; }
    };
  }
  const origAsync = _fs[fn];
  if (origAsync) {
    _fs[fn] = function() {
      const args = Array.from(arguments);
      const cb = typeof args[args.length - 1] === 'function' ? args.pop() : null;
      try { origSync.apply(_fs, args); if (cb) cb(null); }
      catch(e) { if (e.code === 'ENOSYS') { if (cb) cb(null); } else { if (cb) cb(e); else throw e; } }
    };
  }
}

// ====================================================================
// 6. fs.watch — inotify may fail; provide silent no-op fallback
// ====================================================================
const _origWatch = _fs.watch;
_fs.watch = function(filename, options, listener) {
  try { return _origWatch.call(_fs, filename, options, listener); }
  catch(e) {
    if (e.code === 'ENOSYS' || e.code === 'ENOSPC' || e.code === 'ENOENT') {
      // Return a fake watcher that does nothing
      const EventEmitter = require('events');
      const fake = new EventEmitter();
      fake.close = function() {};
      fake.ref = function() { return this; };
      fake.unref = function() { return this; };
      return fake;
    }
    throw e;
  }
};

// ====================================================================
// 7. child_process.spawn — handle ENOSYS (proot) and ENOENT (missing binary).
//    Command-aware mock:
//    - Side-effect cmds (git, node-gyp, cmake, make): return FAILURE (128)
//      so npm doesn't look for files they were supposed to create
//    - Everything else: return SUCCESS (0) — npm internals proceed
//    Handles both ENOSYS (proot syscall fail) and ENOENT (binary not found,
//    e.g. git not installed in rootfs).
// ====================================================================
const _cp = require('child_process');
const _EventEmitter = require('events');

// Commands that produce side effects (files). Must return failure.
function _isSideEffectCmd(cmd) {
  const base = String(cmd).split('/').pop();
  return base === 'git' || base === 'node-gyp' || base === 'cmake' || base === 'make';
}

// Should this error be mocked? ENOSYS always, ENOENT for side-effect cmds.
function _shouldMock(errCode, cmd) {
  if (errCode === 'ENOSYS') return true;
  if (errCode === 'ENOENT' && _isSideEffectCmd(cmd)) return true;
  return false;
}

function _makeFakeChild(exitCode) {
  const fake = new _EventEmitter();
  fake.stdout = new (require('stream').Readable)({ read() { this.push(null); } });
  fake.stderr = new (require('stream').Readable)({ read() { this.push(null); } });
  fake.stdin = new (require('stream').Writable)({ write(c,e,cb) { cb(); } });
  fake.pid = 0;
  fake.exitCode = null;
  fake.kill = function() { return false; };
  fake.ref = function() { return this; };
  fake.unref = function() { return this; };
  fake.connected = false;
  fake.disconnect = function() {};
  process.nextTick(() => {
    fake.exitCode = exitCode;
    fake.emit('close', exitCode, null);
  });
  return fake;
}

function _makeFakeSyncResult(code) {
  return { status: code, signal: null, stdout: Buffer.alloc(0),
           stderr: Buffer.alloc(0),
           pid: 0, output: [null, Buffer.alloc(0), Buffer.alloc(0)],
           error: null };
}

const _origSpawn = _cp.spawn;
_cp.spawn = function(cmd, args, options) {
  try {
    const child = _origSpawn.call(_cp, cmd, args, options);
    child.on('error', (err) => {
      if (_shouldMock(err.code, cmd)) {
        const code = _isSideEffectCmd(cmd) ? 128 : 0;
        child.emit('close', code, null);
      }
    });
    return child;
  } catch(e) {
    if (_shouldMock(e.code, cmd)) {
      return _makeFakeChild(_isSideEffectCmd(cmd) ? 128 : 0);
    }
    throw e;
  }
};
const _origSpawnSync = _cp.spawnSync;
_cp.spawnSync = function(cmd, args, options) {
  try {
    const r = _origSpawnSync.call(_cp, cmd, args, options);
    if (r.error && _shouldMock(r.error.code, cmd)) {
      return _makeFakeSyncResult(_isSideEffectCmd(cmd) ? 128 : 0);
    }
    return r;
  } catch(e) {
    if (_shouldMock(e.code, cmd)) {
      return _makeFakeSyncResult(_isSideEffectCmd(cmd) ? 128 : 0);
    }
    throw e;
  }
};
// Also patch exec/execFile which are wrappers around spawn
const _origExecFile = _cp.execFile;
_cp.execFile = function(file, args, options, cb) {
  if (typeof args === 'function') { cb = args; args = []; options = {}; }
  if (typeof options === 'function') { cb = options; options = {}; }
  try { return _origExecFile.call(_cp, file, args, options, cb); }
  catch(e) {
    if (_shouldMock(e.code, file)) {
      const code = _isSideEffectCmd(file) ? 128 : 0;
      if (cb) cb(code ? Object.assign(new Error('spawn failed'), {code:e.code}) : null, '', '');
      return;
    }
    throw e;
  }
};
const _origExecFileSync = _cp.execFileSync;
_cp.execFileSync = function(file, args, options) {
  try { return _origExecFileSync.call(_cp, file, args, options); }
  catch(e) {
    if (_shouldMock(e.code, file)) {
      if (_isSideEffectCmd(file)) throw e;
      return Buffer.alloc(0);
    }
    throw e;
  }
};
""".trimIndent()
        File(bypassDir, "proot-compat.js").writeText(prootCompatContent)

        // 4. Bionic bypass — comprehensive runtime patcher for openclaw.
        //    Loaded via NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js"
        val bypassContent = """
// OpenClaw Bionic Bypass - Auto-generated
// Comprehensive runtime compatibility layer for proot on Android 10+.
// Loaded via NODE_OPTIONS before any application code runs.

// Load all proot compatibility patches (shared with node-wrapper.js)
require('/root/.openclaw/proot-compat.js');
""".trimIndent()

        File(bypassDir, "bionic-bypass.js").writeText(bypassContent)

        // 5. Git config — write .gitconfig directly to rootfs to avoid shell
        //    quoting issues when running `git config` inside proot via bash -c.
        //    Rewrites SSH URLs to HTTPS (no SSH keys in proot).
        //    npm dependencies like @whiskeysockets/libsignal-node use git+ssh.
        val gitConfig = File("$rootfsDir/root/.gitconfig")
        gitConfig.writeText(
            "[url \"https://github.com/\"]\n" +
            "\tinsteadOf = ssh://git@github.com/\n" +
            "\tinsteadOf = git@github.com:\n" +
            "[advice]\n" +
            "\tdetachedHead = false\n"
        )

        // Patch .bashrc
        val bashrc = File("$rootfsDir/root/.bashrc")
        val exportLine = "export NODE_OPTIONS=\"--require /root/.openclaw/bionic-bypass.js\""

        val existing = if (bashrc.exists()) bashrc.readText() else ""
        if (!existing.contains("bionic-bypass")) {
            bashrc.appendText("\n# OpenClaw Bionic Bypass\n$exportLine\n")
        }
    }

    fun writeResolvConf() {
        val configDir = File(this.configDir)
        configDir.mkdirs()

        File("$configDir/resolv.conf").writeText("nameserver 8.8.8.8\nnameserver 8.8.4.4\n")
    }

    /**
     * Create fake /proc and /sys files that are bind-mounted into proot.
     * Android restricts access to many /proc entries; proot-distro works
     * around this by providing static fake data. We replicate that approach.
     */
    fun setupFakeSysdata() {
        val procDir = File("$configDir/proc_fakes")
        val sysDir = File("$configDir/sys_fakes")
        procDir.mkdirs()
        sysDir.mkdirs()

        // /proc/loadavg
        File(procDir, "loadavg").writeText("0.12 0.07 0.02 2/165 765\n")

        // /proc/stat — matching proot-distro (8 CPUs)
        File(procDir, "stat").writeText(
            "cpu  1957 0 2877 93280 262 342 254 87 0 0\n" +
            "cpu0 31 0 226 12027 82 10 4 9 0 0\n" +
            "cpu1 45 0 290 11498 21 9 8 7 0 0\n" +
            "cpu2 52 0 401 11730 36 15 6 10 0 0\n" +
            "cpu3 42 0 268 11677 31 12 5 8 0 0\n" +
            "cpu4 789 0 720 11364 26 100 83 18 0 0\n" +
            "cpu5 486 0 438 11685 42 86 60 13 0 0\n" +
            "cpu6 314 0 336 11808 45 68 52 11 0 0\n" +
            "cpu7 198 0 198 11491 25 42 36 11 0 0\n" +
            "intr 63361 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0\n" +
            "ctxt 38014093\n" +
            "btime 1694292441\n" +
            "processes 26442\n" +
            "procs_running 1\n" +
            "procs_blocked 0\n" +
            "softirq 75663 0 5903 6 25375 10774 0 243 11685 0 21677\n"
        )

        // /proc/uptime
        File(procDir, "uptime").writeText("124.08 932.80\n")

        // /proc/version — fake kernel info matching proot-distro v4.37.0
        File(procDir, "version").writeText(
            "Linux version ${ProcessManager.FAKE_KERNEL_RELEASE} (proot@termux) " +
            "(gcc (GCC) 13.3.0, GNU ld (GNU Binutils) 2.42) " +
            "${ProcessManager.FAKE_KERNEL_VERSION}\n"
        )

        // /proc/vmstat — matching proot-distro format
        File(procDir, "vmstat").writeText(
            "nr_free_pages 1743136\n" +
            "nr_zone_inactive_anon 179281\n" +
            "nr_zone_active_anon 7183\n" +
            "nr_zone_inactive_file 22858\n" +
            "nr_zone_active_file 51328\n" +
            "nr_zone_unevictable 642\n" +
            "nr_zone_write_pending 0\n" +
            "nr_mlock 0\n" +
            "nr_slab_reclaimable 7520\n" +
            "nr_slab_unreclaimable 10776\n" +
            "pgpgin 198292\n" +
            "pgpgout 7674\n" +
            "pswpin 0\n" +
            "pswpout 0\n" +
            "pgalloc_dma 0\n" +
            "pgalloc_dma32 0\n" +
            "pgalloc_normal 44669136\n" +
            "pgfree 46674674\n" +
            "pgactivate 1085674\n" +
            "pgdeactivate 340776\n" +
            "pglazyfree 139872\n" +
            "pgfault 37291463\n" +
            "pgmajfault 6854\n" +
            "pgrefill 480634\n"
        )

        // /proc/sys/kernel/cap_last_cap
        File(procDir, "cap_last_cap").writeText("40\n")

        // /proc/sys/fs/inotify/max_user_watches
        File(procDir, "max_user_watches").writeText("4096\n")

        // /proc/sys/crypto/fips_enabled — libgcrypt reads this on startup;
        // missing/unreadable on Android causes apt HTTP method to SIGABRT
        File(procDir, "fips_enabled").writeText("0\n")

        // Empty file for /sys/fs/selinux bind
        File(sysDir, "empty").writeText("")
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
