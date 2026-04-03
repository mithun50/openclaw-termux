# 从 Termux 仓库下载 proot 和 libtalloc，解压放到 jniLibs
# 在 Windows PowerShell 中运行

$TERMUX_REPO = "https://packages.termux.dev/apt/termux-main"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$JNILIBS_DIR = "$SCRIPT_DIR\..\flutter_app\android\app\jniLibs"
$TMP_DIR = "$env:TEMP\proot-fetch-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TMP_DIR | Out-Null

$env:HTTPS_PROXY = "http://127.0.0.1:7897"
$env:HTTP_PROXY  = "http://127.0.0.1:7897"

function Get-TermuxPkgUrl($arch, $pkgName) {
    $indexUrl = "$TERMUX_REPO/dists/stable/main/binary-$arch/Packages"
    $index = (Invoke-WebRequest -Uri $indexUrl -UseBasicParsing -Proxy "http://127.0.0.1:7897").Content
    $lines = $index -split "`n"
    $inPkg = $false
    foreach ($line in $lines) {
        if ($line -match "^Package: $pkgName$") { $inPkg = $true }
        if ($inPkg -and $line -match "^Filename: (.+)") {
            return "$TERMUX_REPO/$($Matches[1].Trim())"
        }
        if ($inPkg -and $line -eq "") { $inPkg = $false }
    }
    return $null
}

function Extract-Deb($debPath, $outDir) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    # .deb 是 ar 格式，用 7-Zip 或手动解析
    # 尝试用 7-Zip
    $7z = "C:\Program Files\7-Zip\7z.exe"
    if (Test-Path $7z) {
        & $7z e $debPath -o"$outDir" "data.tar*" -y | Out-Null
        $dataTar = Get-ChildItem $outDir -Filter "data.tar*" | Select-Object -First 1
        if ($dataTar) {
            & $7z x $dataTar.FullName -o"$outDir\data" -y | Out-Null
        }
    } else {
        Write-Host "  Please install 7-Zip: https://www.7-zip.org/" -ForegroundColor Red
        exit 1
    }
}

$abis = @(
    @{ jni = "arm64-v8a";   deb = "aarch64"; find = "aarch64" },
    @{ jni = "armeabi-v7a"; deb = "arm";     find = "arm" },
    @{ jni = "x86_64";      deb = "x86_64";  find = "x86_64" }
)

foreach ($abi in $abis) {
    $jniAbi  = $abi.jni
    $debArch = $abi.deb
    $outDir  = "$JNILIBS_DIR\$jniAbi"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    Write-Host "[$jniAbi] Fetching proot..." -ForegroundColor Cyan
    $prootUrl = Get-TermuxPkgUrl $debArch "proot"
    if (-not $prootUrl) { Write-Host "  proot package not found" -ForegroundColor Red; continue }

    $prootDeb = "$TMP_DIR\proot-$debArch.deb"
    Invoke-WebRequest -Uri $prootUrl -OutFile $prootDeb -UseBasicParsing -Proxy "http://127.0.0.1:7897"
    Extract-Deb $prootDeb "$TMP_DIR\proot-$debArch"

    Write-Host "[$jniAbi] Fetching libtalloc..." -ForegroundColor Cyan
    $tallocUrl = Get-TermuxPkgUrl $debArch "libtalloc"
    if (-not $tallocUrl) { Write-Host "  libtalloc package not found" -ForegroundColor Red; continue }

    $tallocDeb = "$TMP_DIR\talloc-$debArch.deb"
    Invoke-WebRequest -Uri $tallocUrl -OutFile $tallocDeb -UseBasicParsing -Proxy "http://127.0.0.1:7897"
    Extract-Deb $tallocDeb "$TMP_DIR\talloc-$debArch"

    # 复制 proot 二进制
    $prootBin = Get-ChildItem "$TMP_DIR\proot-$debArch\data" -Recurse -Filter "proot" | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1
    if ($prootBin) {
        Copy-Item $prootBin.FullName "$outDir\libproot.so" -Force
        Write-Host "  libproot.so OK ($([math]::Round($prootBin.Length/1KB))KB)"
    }

    # 复制 loader
    $loader = Get-ChildItem "$TMP_DIR\proot-$debArch\data" -Recurse -Filter "loader" | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1
    if ($loader) {
        Copy-Item $loader.FullName "$outDir\libprootloader.so" -Force
        Write-Host "  libprootloader.so OK"
    }

    # 复制 libtalloc
    $talloc = Get-ChildItem "$TMP_DIR\talloc-$debArch\data" -Recurse | Where-Object { $_.Name -like "libtalloc.so*" -and -not $_.PSIsContainer } | Select-Object -First 1
    if ($talloc) {
        Copy-Item $talloc.FullName "$outDir\libtalloc.so" -Force
        Write-Host "  libtalloc.so OK"
    }

    Write-Host "[$jniAbi] Done" -ForegroundColor Green
}

Remove-Item -Recurse -Force $TMP_DIR -ErrorAction SilentlyContinue
Write-Host "`nAll done! Now rebuild the APK." -ForegroundColor Green
