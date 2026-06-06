@echo off
REM Simple wrapper so you can double-click to launch HOLLOW on Windows.
REM Passes any args through (e.g. -Clean)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_hollow.ps1" %*