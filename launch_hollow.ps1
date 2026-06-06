#!/usr/bin/env pwsh
# Convenience launcher for HOLLOW horror demo on Windows
# - Cleans .godot cache after edits (prevents stale resources) with -Clean
# - Always starts clean (no persistent saves for the demo experience)
#
# Usage:
#   From anywhere:
#     C:\Users\PC\Projects\hollow\launch_hollow.ps1
#   Or from inside the hollow folder:
#     .\launch_hollow.ps1
#   Force clean reimport:
#     .\launch_hollow.ps1 -Clean
#
# Godot 4.6+ is required. The script will attempt to locate a Godot executable.
# If it can't find one, it prints instructions.

param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

# Always run from the script's own directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir

Write-Host "=== HOLLOW launcher (Windows) ===" -ForegroundColor Cyan
Write-Host "Location: $(Get-Location)" -ForegroundColor Gray

# .godot cache handling
if ($Clean) {
    Write-Host "CLEAN detected: removing .godot cache..." -ForegroundColor Yellow
    if (Test-Path ".godot") {
        Remove-Item -Recurse -Force ".godot"
    }
} else {
    Write-Host "(Using existing .godot cache for faster startup. Pass -Clean to force a full reimport.)" -ForegroundColor DarkGray
}

# Always start the game state fresh (no carry-over progress) for the intended horror experience.
$userDataPath = Join-Path $env:APPDATA "Godot\app_userdata\HOLLOW"
Write-Host "Preparing clean demo start (removing previous play data)..." -ForegroundColor Gray
if (Test-Path $userDataPath) {
    Remove-Item -Recurse -Force $userDataPath -ErrorAction SilentlyContinue
}

# Attempt to locate Godot executable
function Find-Godot {
    $candidates = @()

    # 1. In PATH
    $inPath = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    $inPath2 = Get-Command "Godot" -ErrorAction SilentlyContinue
    if ($inPath2) { return $inPath2.Source }

    # 2. Common portable / install locations (expand globs)
    $searchPaths = @(
        "$env:LOCALAPPDATA\Programs\Godot\Godot.exe",
        "$env:LOCALAPPDATA\Godot\Godot.exe",
        "$env:USERPROFILE\Downloads\*Godot*.exe",
        "$env:USERPROFILE\Downloads\Godot*\Godot*.exe",
        "C:\Godot\Godot*.exe",
        "C:\Tools\Godot\Godot*.exe",
        "$env:ProgramFiles\Godot\Godot.exe",
        "$env:ProgramFiles(x86)\Godot\Godot.exe",
        "$env:ProgramFiles\Godot Engine*\Godot.exe"
    )

    foreach ($pattern in $searchPaths) {
        $items = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        if ($items) {
            # Prefer non-console if both exist, but take first match for simplicity
            $preferred = $items | Where-Object { $_.Name -notlike "*console*" } | Select-Object -First 1
            if ($preferred) { return $preferred.FullName }
            return $items[0].FullName
        }
    }

    # 3. Look under user profile more broadly but shallow (recent downloads etc)
    $userGodots = Get-ChildItem "$env:USERPROFILE" -Recurse -Filter "*Godot*.exe" -ErrorAction SilentlyContinue -Depth 3 |
        Where-Object { $_.Name -like "*Godot*" -and $_.Name -like "*.exe" } |
        Select-Object -First 1
    if ($userGodots) { return $userGodots.FullName }

    return $null
}

$godotBin = Find-Godot

if (-not $godotBin) {
    Write-Host ""
    Write-Host "ERROR: Godot binary not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "You can still run the demo by:" -ForegroundColor Yellow
    Write-Host "  1. Download Godot 4.6+ (Windows) from https://godotengine.org/download" -ForegroundColor White
    Write-Host "  2. Extract the zip (portable) or run the installer." -ForegroundColor White
    Write-Host "  3. Either:" -ForegroundColor White
    Write-Host "     - Add the Godot folder containing Godot.exe to your PATH, or" -ForegroundColor White
    Write-Host "     - Open File Explorer, navigate to this folder (Projects\hollow), and drag the folder onto Godot.exe, or" -ForegroundColor White
    Write-Host "     - In Godot: Project -> Open Project -> select the hollow folder containing project.godot" -ForegroundColor White
    Write-Host ""
    Write-Host "To make this script work automatically next time, place Godot.exe in one of the searched locations" -ForegroundColor Gray
    Write-Host "or edit this script to hardcode `$godotBin = 'full\path\to\Godot.exe'" -ForegroundColor Gray
    exit 1
}

Write-Host "Launching HOLLOW using: $godotBin" -ForegroundColor Green
Write-Host ""
Write-Host "Controls:" -ForegroundColor Cyan
Write-Host "  WASD          Walk" 
Write-Host "  Mouse         Look (click in 3D view to capture mouse)"
Write-Host "  Shift         Sprint (light drains faster)"
Write-Host "  F             Toggle flashlight"
Write-Host "  E             Examine / interact"
Write-Host "  Tab / J       Open Journal (collected documents)"
Write-Host "  Esc           Pause / restart / return to menu"
Write-Host ""
Write-Host "The launcher forces a completely fresh game state (no progress carry-over)." -ForegroundColor DarkGray
Write-Host ""

& $godotBin --path . $args
exit $LASTEXITCODE
