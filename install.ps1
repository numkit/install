# install.ps1 — Official Windows PowerShell bootstrapper for NumKit
param(
    [string]$Prefix = "$HOME\.numkit",
    [switch]$NoSimd = $false,
    [switch]$NoCodegen = $false,
    [switch]$AllToolboxes = $false,
    [string[]]$Toolboxes = @(),
    [switch]$UseZig = $false,
    [int]$Jobs = [Environment]::ProcessorCount
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$srcDir       = Join-Path $Prefix "src"
$binDir       = Join-Path $Prefix "bin"
$modDir       = Join-Path $Prefix "modules"
$toolchainDir = Join-Path $Prefix "toolchain"
New-Item -ItemType Directory -Force -Path $srcDir, $binDir, $modDir, $toolchainDir | Out-Null

function Invoke-FastDownload([string]$url, [string]$outFile) {
    $curlExe = "$env:SystemRoot\System32\curl.exe"
    if (Test-Path $curlExe) {
        & $curlExe -fL --retry 3 -o $outFile $url | Out-Host
        if ($LASTEXITCODE -eq 0 -and (Test-Path $outFile)) { return }
    }
    Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing | Out-Null
}

function Invoke-FastExtract([string]$zipPath, [string]$destDir) {
    if (Test-Path $destDir) { Remove-Item -Recurse -Force $destDir }
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $tarExe = "$env:SystemRoot\System32\tar.exe"
    if (Test-Path $tarExe) {
        & $tarExe -xf $zipPath -C $destDir | Out-Host
        if ($LASTEXITCODE -eq 0) { return }
    }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $destDir)
}

function Ensure-Git {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files\Git\bin\git.exe",
        "C:\Program Files (x86)\Git\cmd\git.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "==> Installing Git via winget..." -ForegroundColor Yellow
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements | Out-Host
        if (Test-Path "C:\Program Files\Git\cmd\git.exe") {
            return "C:\Program Files\Git\cmd\git.exe"
        }
    }
    throw "Git not found. Please install Git (https://git-scm.com/)."
}

function Ensure-Zig {
    $portableZig = Join-Path $toolchainDir "zig\zig.exe"
    if (Test-Path $portableZig) { return $portableZig }

    $cmd = Get-Command zig -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $zigVer = "0.13.0"
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "aarch64" } else { "x86_64" }
    $zipName = "zig-windows-$arch-$zigVer"
    $url = "https://ziglang.org/download/$zigVer/$zipName.zip"
    $zipPath = Join-Path $toolchainDir "$zipName.zip"
    $extractDir = Join-Path $toolchainDir "zig_tmp"
    $destDir = Join-Path $toolchainDir "zig"

    Write-Host "==> Downloading portable Zig C++ toolchain ($zigVer)..." -ForegroundColor Cyan
    Invoke-FastDownload $url $zipPath
    Write-Host "==> Extracting Zig C++ toolchain..." -ForegroundColor Cyan
    Invoke-FastExtract $zipPath $extractDir
    if (Test-Path $destDir) { Remove-Item -Recurse -Force $destDir }
    Move-Item -Path (Join-Path $extractDir $zipName) -Destination $destDir
    Remove-Item -Recurse -Force $extractDir, $zipPath -ErrorAction SilentlyContinue
    return $portableZig
}

function Ensure-CMake {
    $portableCMake = Join-Path $toolchainDir "cmake\bin\cmake.exe"
    if (Test-Path $portableCMake) { return $portableCMake }

    $cmd = Get-Command cmake -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "C:\Program Files\CMake\bin\cmake.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    $cmakeVer = "3.30.5"
    $zipName = "cmake-$cmakeVer-windows-x86_64"
    $url = "https://github.com/Kitware/CMake/releases/download/v$cmakeVer/$zipName.zip"
    $zipPath = Join-Path $toolchainDir "$zipName.zip"
    $extractDir = Join-Path $toolchainDir "cmake_tmp"
    $destDir = Join-Path $toolchainDir "cmake"

    Write-Host "==> Downloading portable CMake ($cmakeVer)..." -ForegroundColor Cyan
    Invoke-FastDownload $url $zipPath
    Invoke-FastExtract $zipPath $extractDir
    if (Test-Path $destDir) { Remove-Item -Recurse -Force $destDir }
    Move-Item -Path (Join-Path $extractDir $zipName) -Destination $destDir
    Remove-Item -Recurse -Force $extractDir, $zipPath -ErrorAction SilentlyContinue
    return $portableCMake
}

function Ensure-Ninja {
    $portableNinja = Join-Path $toolchainDir "ninja\ninja.exe"
    if (Test-Path $portableNinja) { return $portableNinja }

    $cmd = Get-Command ninja -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    $ninjaVer = "1.12.1"
    $url = "https://github.com/ninja-build/ninja/releases/download/v$ninjaVer/ninja-win.zip"
    $zipPath = Join-Path $toolchainDir "ninja-win.zip"
    $destDir = Join-Path $toolchainDir "ninja"

    Write-Host "==> Downloading portable Ninja ($ninjaVer)..." -ForegroundColor Cyan
    Invoke-FastDownload $url $zipPath
    Invoke-FastExtract $zipPath $destDir
    Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    return $portableNinja
}

function Test-HasMsvc {
    $vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return $false }
    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    return (-not [string]::IsNullOrWhiteSpace($vsPath))
}

$git   = Ensure-Git
$cmake = Ensure-CMake
$zig   = Ensure-Zig
$hasMsvc = Test-HasMsvc
$useZigForBuild = $UseZig -or (-not $hasMsvc)
$ninja = if ($useZigForBuild) { Ensure-Ninja } else { "" }
$simdFlag = if ($NoSimd) { "OFF" } else { "ON" }

Write-Host "==> NumKit Windows Source Installer" -ForegroundColor Cyan
Write-Host "    Prefix:    $Prefix"
Write-Host "    CMake:     $cmake"
Write-Host "    Zig C++:   $zig"
Write-Host "    Toolchain: $(if ($useZigForBuild) { 'Zig C++ + Ninja' } else { 'MSVC + Zig AOT' })"
Write-Host "    SIMD:      $simdFlag"
Write-Host "    Jobs:      $Jobs"

function Sync-Repo([string]$name) {
    $target = Join-Path $srcDir $name
    if (Test-Path (Join-Path $target ".git")) {
        Write-Host "==> Updating numkit/$name..." -ForegroundColor Yellow
        & $git -C $target pull --ff-only origin main | Out-Host
    } else {
        Write-Host "==> Cloning numkit/$name..." -ForegroundColor Green
        & $git clone --depth 1 "https://github.com/numkit/$name.git" $target | Out-Host
    }
}

function Invoke-CMakeBuild([string]$projSrc) {
    $projBuild = Join-Path $projSrc "build"
    $cfgArgs = @(
        "-Wno-deprecated",
        "-S", $projSrc,
        "-B", $projBuild,
        "-DCMAKE_BUILD_TYPE=Release",
        "-DNUMKIT_WITH_SIMD=$simdFlag",
        "-DNUMKIT_BUILD_TESTS=OFF",
        "-DNUMKIT_SYS_BUILD_TESTS=OFF"
    )
    if ($useZigForBuild -and -not (Test-Path (Join-Path $projBuild "CMakeCache.txt"))) {
        $cfgArgs += @(
            "-G", "Ninja",
            "-DCMAKE_MAKE_PROGRAM=$ninja",
            "-DCMAKE_CXX_COMPILER=$zig",
            "-DCMAKE_CXX_COMPILER_ARG1=c++",
            "-DCMAKE_C_COMPILER=$zig",
            "-DCMAKE_C_COMPILER_ARG1=cc"
        )
    }
    & $cmake @cfgArgs | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed for $projSrc" }
    & $cmake --build $projBuild --config Release --parallel $Jobs | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "CMake build failed for $projSrc" }
    return $projBuild
}

function Find-BuiltBinary([string]$buildDir, [string]$fileName) {
    $candidates = @(
        (Join-Path $buildDir "Release\$fileName"),
        (Join-Path $buildDir "bin\Release\$fileName"),
        (Join-Path $buildDir "bin\$fileName"),
        (Join-Path $buildDir $fileName)
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    $found = Get-ChildItem -Path $buildDir -Filter $fileName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.FullName }
    throw "Could not find built binary '$fileName' under $buildDir"
}

$coreRepos = @("value", "sys", "ops", "numkit")
if (-not $NoCodegen) { $coreRepos += "codegen" }
foreach ($repo in $coreRepos) {
    Sync-Repo $repo
}

Write-Host "==> Building numkit/numkit runtime & CLI..." -ForegroundColor Cyan
$coreBuild = Invoke-CMakeBuild (Join-Path $srcDir "numkit")
$exePath = Find-BuiltBinary $coreBuild "numkit.exe"
Copy-Item -Force $exePath (Join-Path $binDir "numkit.exe")

if (-not $NoCodegen) {
    Write-Host "==> Building numkit/codegen AOT transpiler..." -ForegroundColor Cyan
    $cgBuild = Invoke-CMakeBuild (Join-Path $srcDir "codegen")
    $cgExe = Find-BuiltBinary $cgBuild "numkit_codegen.exe"
    Copy-Item -Force $cgExe (Join-Path $binDir "numkit_codegen.exe")
}

$selectedToolboxes = @()
if ($AllToolboxes) {
    $selectedToolboxes = @("signal", "wavelet", "stats", "control", "audio", "comm", "image")
} elseif ($Toolboxes.Count -gt 0) {
    foreach ($item in $Toolboxes) {
        $selectedToolboxes += ($item -split "," | Where-Object { $_ -ne "" })
    }
}

foreach ($tb in $selectedToolboxes) {
    Sync-Repo $tb
    Write-Host "==> Building toolbox numkit/$tb..." -ForegroundColor Cyan
    $tbSrc = Join-Path $srcDir $tb
    $tbBuild = Invoke-CMakeBuild $tbSrc
    $tbModDir = Join-Path $modDir $tb
    New-Item -ItemType Directory -Force -Path $tbModDir | Out-Null
    Copy-Item -Force (Join-Path $tbSrc "manifest.json") (Join-Path $tbModDir "manifest.json")
    $dllPath = Find-BuiltBinary $tbBuild "numkit_$tb.dll"
    Copy-Item -Force $dllPath (Join-Path $tbModDir "numkit_$tb.dll")
}

# Add ~/.numkit/bin to User PATH if not already present
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) { $userPath = "" }
if ($userPath -notlike "*$binDir*") {
    $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $binDir } else { "$userPath;$binDir" }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$env:Path;$binDir"
    Write-Host "==> Added '$binDir' to your User PATH." -ForegroundColor Green
}

Write-Host ""
Write-Host "==> NumKit installed successfully to $binDir\numkit.exe" -ForegroundColor Green
if (-not $NoCodegen) {
    Write-Host "==> AOT transpiler installed to $binDir\numkit_codegen.exe (powered by Zig C++)" -ForegroundColor Green
}
