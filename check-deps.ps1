# Checks what the gallery needs before it starts.
# Exit code 1 = something must be fixed first; warnings don't stop the gallery.
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8080
$script:fail = 0
$script:warn = 0
function Ok($m)   { Write-Host "  [ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [WARN] $m" -ForegroundColor Yellow; $script:warn++ }
function Bad($m)  { Write-Host "  [FAIL] $m" -ForegroundColor Red; $script:fail++ }
function Info($m) { Write-Host "         $m" -ForegroundColor DarkGray }

# newer TLS so the online checks work on older Windows setups
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

Write-Host ""
Write-Host "Checking what the gallery needs..." -ForegroundColor Cyan

# 1. PowerShell and the built-in web server
$v = $PSVersionTable.PSVersion
if ($v.Major -ge 5) { Ok "PowerShell $v" } else { Bad "PowerShell $v is too old - install Windows Management Framework 5.1" }
try { $null = New-Object System.Net.HttpListener; Ok ".NET web server (HttpListener)" }
catch { Bad ".NET HttpListener isn't available - install .NET Framework 4.8" }

# 2. Project files
foreach ($f in @('index.html', 'serve.ps1')) {
  if (Test-Path -LiteralPath (Join-Path $root $f)) { Ok $f } else { Bad "$f is missing from $root" }
}

# 3. Your pictures and videos
$img = Join-Path $root 'images'
if (Test-Path -LiteralPath $img) {
  $n = @(Get-ChildItem -LiteralPath $img -Recurse -File -ErrorAction SilentlyContinue |
         Where-Object { $_.Extension -match '^\.(jpe?g|png|gif|webp|bmp|svg|avif|mp4|webm|ogv|mov|avi|mkv)$' }).Count
  if ($n -gt 0) { Ok "images folder ($n pictures and videos)" } else { Warn "images folder is empty - add your pictures and videos to it" }
} else {
  New-Item -ItemType Directory -Path $img | Out-Null
  Warn "images folder was missing - created it; put your pictures and videos in it"
}

# 4. Saving editor work (censor areas, beat maps, light schedules)
try {
  $d = Join-Path $img '.gallery-data'
  New-Item -ItemType Directory -Force -Path $d -ErrorAction Stop | Out-Null
  $t = Join-Path $d '.write-test'
  Set-Content -LiteralPath $t -Value 'ok' -ErrorAction Stop
  Remove-Item -LiteralPath $t -Force -ErrorAction Stop
  Ok "can save editor work to images\.gallery-data"
} catch { Warn "can't write to images\.gallery-data - editor work will only be kept in the browser" }

# 5. Port: each copy of the gallery uses its own (8080, or the next free one, remembered in private\)
$ProgressPreference = 'SilentlyContinue'
$idFile = Join-Path $root 'private\.server-id'
$myId = ''
if (Test-Path -LiteralPath $idFile) { $myId = (Get-Content -LiteralPath $idFile -Raw).Trim() }
$pf = Join-Path $root 'private\.server-port'
if (Test-Path -LiteralPath $pf) { $saved = 0; if ([int]::TryParse((Get-Content -LiteralPath $pf -Raw).Trim(), [ref]$saved)) { $port = $saved } }
$free = $true
try { $l = New-Object System.Net.HttpListener; $l.Prefixes.Add("http://localhost:$port/"); $l.Start(); $l.Stop(); $l.Close() }
catch { $free = $false }
if ($free) { Ok "port $port is free" }
else {
  $same = $false
  try { $r = Invoke-WebRequest "http://localhost:$port/__id" -UseBasicParsing -TimeoutSec 2; $same = [bool]$myId -and ("$($r.Content)".Trim() -eq $myId) } catch {}
  if ($same) { Ok "this gallery is already running on port $port" }
  else { Ok "port $port is busy (another copy of the gallery, or another program) - this copy will use the next free port" }
}

# 6. Online parts: face/body detection and the censor models load from the internet on first use
$html = ''
try { $html = Get-Content -LiteralPath (Join-Path $root 'index.html') -Raw -ErrorAction Stop } catch {}
$mp = '0.10.14'; if ($html -match "const MP_VER = '([^']+)'") { $mp = $matches[1] }
$ort = '1.20.1'; if ($html -match "const ORT_VER = '([^']+)'") { $ort = $matches[1] }
$sites = [ordered]@{
  'cdn.jsdelivr.net (detection + censor libraries)' = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@$mp/package.json"
  'storage.googleapis.com (body + face models)'     = 'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task'
  'huggingface.co (precise censor model)'           = 'https://huggingface.co/deepghs/nudenet_onnx/resolve/main/320n.onnx'
}
$sites["cdn.jsdelivr.net (onnxruntime-web $ort)"] = "https://cdn.jsdelivr.net/npm/onnxruntime-web@$ort/package.json"
$offline = 0
foreach ($k in $sites.Keys) {
  try { $null = Invoke-WebRequest $sites[$k] -Method Head -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop; Ok "online: $k" }
  catch { Warn "can't reach $k"; $offline++ }
}
if ($offline) { Info "Offline, the gallery still works, but zoom, auto censor and the precise censor need these the first time." }

# 7. Optional: the large precise censor model
if (Test-Path -LiteralPath (Join-Path $root 'models\nudenet-640m.onnx')) { Ok "large precise censor model (models\nudenet-640m.onnx)" }
else { Info "optional: models\nudenet-640m.onnx isn't there - only needed for 'Precise large' (see models\README.txt)" }

# 8. Browser: Chrome or Edge for the graphics-card censor, GIF censoring and the eyedropper
$found = $null
foreach ($exe in @('chrome.exe', 'msedge.exe')) {
  foreach ($hive in @('HKCU:', 'HKLM:')) {
    $p = (Get-ItemProperty -Path "$hive\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$exe" -ErrorAction SilentlyContinue).'(default)'
    if ($p -and (Test-Path -LiteralPath $p)) {
      $name = if ($exe -eq 'chrome.exe') { 'Google Chrome' } else { 'Microsoft Edge' }
      $found = "$name $((Get-Item -LiteralPath $p).VersionInfo.ProductVersion)"
      break
    }
  }
  if ($found) { break }
}
if ($found) { Ok "browser: $found" } else { Warn "Chrome or Edge not found - other browsers miss the graphics-card censor, GIF censoring and the eyedropper" }

# summary
Write-Host ""
if ($script:fail) { Write-Host "$($script:fail) problem(s) need fixing before the gallery can start." -ForegroundColor Red; exit 1 }
elseif ($script:warn) { Write-Host "Ready, with $($script:warn) warning(s) above." -ForegroundColor Yellow }
else { Write-Host "Everything's ready." -ForegroundColor Green }
Write-Host ""
exit 0
