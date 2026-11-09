@echo off
REM Scans the "images" folder (including subfolders), writes private\media-list.js (never committed), then serves the gallery at http://localhost:8080
cd /d "%~dp0"
REM Check what the gallery needs first (see check-deps.ps1)
where powershell >nul 2>nul || (echo PowerShell is missing - the gallery needs Windows PowerShell 5.1. & pause & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-deps.ps1"
if errorlevel 1 (
  echo Fix the problems above, then run this again.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root = (Resolve-Path 'images').Path;" ^
  "$files = Get-ChildItem -Path $root -Recurse -File | Where-Object { $_.Extension -match '^\.(jpe?g|png|gif|webp|bmp|svg|avif|mp4|webm|ogv|mov|avi|mkv)$' } | ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\','/') };" ^
  "$json = ConvertTo-Json -InputObject @($files) -Compress;" ^
  "New-Item -ItemType Directory -Force -Path 'private' | Out-Null;" ^
  "Set-Content -Path 'private\media-list.js' -Value ('window.GALLERY_IMAGES = ' + $json + ';') -Encoding UTF8;" ^
  "Write-Host ('Found ' + @($files).Count + ' item(s).')"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
