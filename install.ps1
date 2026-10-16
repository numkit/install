# install.ps1 — Official Windows PowerShell bootstrapper for NumKit
param(
    [string]$Prefix = "$HOME\.numkit",
    [switch]$NoSimd = $false,
    [switch]$AllToolboxes = $false,
    [int]$Jobs = [Environment]::ProcessorCount
)

$ErrorActionPreference = "Stop"

function Find-CMake {
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
    throw "CMake not found. Please install CMake or Visual Studio C++ Build Tools."
}

$cmake = Find-CMake
$simdFlag = if ($NoSimd) { "OFF" } else { "ON" }

Write-Host "==> NumKit Windows Installer" -ForegroundColor Cyan
Write-Host "    Prefix: $Prefix"
Write-Host "    CMake:  $cmake"
Write-Host "    SIMD:   $simdFlag"
Write-Host "    Jobs:   $Jobs"

$srcDir = Join-Path $Prefix "src"
$binDir = Join-Path $Prefix "bin"
$modDir = Join-Path $Prefix "modules"
New-Item -ItemType Directory -Force -Path $srcDir, $binDir, $modDir | Out-Null

function Sync-Repo([string]$name) {
    $target = Join-Path $srcDir $name
    if (Test-Path (Join-Path $target ".git")) {
        Write-Host "==> Updating numkit/$name..." -ForegroundColor Yellow
        git -C $target pull --ff-only origin main
    } else {
        Write-Host "==> Cloning numkit/$name..." -ForegroundColor Green
        git clone --depth 1 "https://github.com/numkit/$name.git" $target
    }
}

foreach ($repo in @("value", "sys", "ops", "numkit")) {
    Sync-Repo $repo
}

Write-Host "==> Configuring and building numkit core..." -ForegroundColor Cyan
$coreSrc = Join-Path $srcDir "numkit"
$coreBuild = Join-Path $coreSrc "build"
& $cmake -S $coreSrc -B $coreBuild "-DNUMKIT_WITH_SIMD=$simdFlag"
& $cmake --build $coreBuild --config Release --parallel $Jobs

$exePath = Join-Path $coreBuild "Release\numkit.exe"
if (-not (Test-Path $exePath)) { $exePath = Join-Path $coreBuild "numkit.exe" }
Copy-Item -Force $exePath (Join-Path $binDir "numkit.exe")

$codegenPath = Join-Path $coreBuild "Release\numkit_codegen.exe"
if (Test-Path $codegenPath) {
    Copy-Item -Force $codegenPath (Join-Path $binDir "numkit_codegen.exe")
}

if ($AllToolboxes) {
    foreach ($tb in @("signal", "wavelet", "stats", "control", "audio", "comm", "image")) {
        Sync-Repo $tb
        Write-Host "==> Building toolbox numkit/$tb..." -ForegroundColor Cyan
        $tbSrc = Join-Path $srcDir $tb
        $tbBuild = Join-Path $tbSrc "build"
        & $cmake -S $tbSrc -B $tbBuild "-DNUMKIT_WITH_SIMD=$simdFlag"
        & $cmake --build $tbBuild --config Release --parallel $Jobs
        $tbModDir = Join-Path $modDir $tb
        New-Item -ItemType Directory -Force -Path $tbModDir | Out-Null
        Copy-Item -Force (Join-Path $tbSrc "manifest.json") (Join-Path $tbModDir "manifest.json")
        $dllPath = Join-Path $tbBuild "Release\numkit_$tb.dll"
        if (-not (Test-Path $dllPath)) { $dllPath = Join-Path $tbBuild "numkit_$tb.dll" }
        Copy-Item -Force $dllPath (Join-Path $tbModDir "numkit_$tb.dll")
    }
}

Write-Host ""
Write-Host "==> NumKit installed successfully to $binDir\numkit.exe" -ForegroundColor Green
Write-Host "    Add '$binDir' to your PATH to run 'numkit' from any terminal."
