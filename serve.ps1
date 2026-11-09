# Tiny local web server for the gallery (needed so face detection can read the images)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProgressPreference = 'SilentlyContinue'

# Each copy of the gallery has its own ID and its own port, so two copies never show each other's media.
$privDir = Join-Path $root 'private'
New-Item -ItemType Directory -Force -Path $privDir | Out-Null
$idFile = Join-Path $privDir '.server-id'
$myId = ''
if (Test-Path -LiteralPath $idFile) { $myId = (Get-Content -LiteralPath $idFile -Raw).Trim() }
if (-not $myId) { $myId = [guid]::NewGuid().ToString(); Set-Content -LiteralPath $idFile -Value $myId -NoNewline }
$portFile = Join-Path $privDir '.server-port'
$port = 8080
if (Test-Path -LiteralPath $portFile) {
  $saved = 0
  if ([int]::TryParse((Get-Content -LiteralPath $portFile -Raw).Trim(), [ref]$saved) -and $saved -gt 1023 -and $saved -lt 65500) { $port = $saved }
}

$listener = $null
for ($try = 0; $try -lt 20; $try++) {
  $candidate = $port + $try
  # this same copy is already running there: just open it
  try {
    $r = Invoke-WebRequest "http://localhost:$candidate/__id" -UseBasicParsing -TimeoutSec 2
    if ("$($r.Content)".Trim() -eq $myId) {
      Write-Host "This gallery is already running - opening it."
      Start-Process "http://localhost:$candidate/"
      exit
    }
  } catch {}
  # otherwise take the port if it's free; if another copy or program has it, try the next one
  $l = New-Object System.Net.HttpListener
  $l.Prefixes.Add("http://localhost:$candidate/")
  try { $l.Start(); $listener = $l; $port = $candidate; break } catch { $l.Close() }
}
if (-not $listener) {
  Write-Host "Couldn't find a free port from $port to $($port + 19). Close other programs using them and try again."
  Read-Host 'Press Enter to close'
  exit 1
}
Set-Content -LiteralPath $portFile -Value $port -NoNewline   # use the same port next time
Write-Host "Gallery running at http://localhost:$port/  -  close this window to stop it."
Start-Process "http://localhost:$port/"

$types = @{
  '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.css'='text/css'
  '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.gif'='image/gif'; '.webp'='image/webp'
  '.bmp'='image/bmp'; '.svg'='image/svg+xml'; '.avif'='image/avif'
  '.mp4'='video/mp4'; '.webm'='video/webm'; '.ogv'='video/ogg'; '.mov'='video/quicktime'
  '.mkv'='video/x-matroska'; '.avi'='video/x-msvideo'
  '.mp3'='audio/mpeg'; '.wav'='audio/wav'; '.ogg'='audio/ogg'; '.m4a'='audio/mp4'; '.flac'='audio/flac'
}

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $res = $ctx.Response
  try {
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ($rel -eq '') { $rel = 'index.html' }
    $method = $ctx.Request.HttpMethod
    if ($method -ne 'GET' -and $method -ne 'HEAD') {
      # Saving: only PUT /__data/censor|beats|lights, only from this gallery, written to images\.gallery-data\
      $origin = $ctx.Request.Headers['Origin']
      if ($method -eq 'PUT' -and $rel -match '^__data/(censor|beats|lights)$' -and (-not $origin -or $origin -eq "http://localhost:$port")) {
        $name = $matches[1]
        if ($ctx.Request.ContentLength64 -gt 20MB) { $res.StatusCode = 413 }
        else {
          $reader = New-Object IO.StreamReader($ctx.Request.InputStream, [Text.Encoding]::UTF8)
          $body = $reader.ReadToEnd(); $reader.Close()
          $valid = $true
          try { $null = $body | ConvertFrom-Json -ErrorAction Stop } catch { $valid = $false }
          if (-not $valid) { $res.StatusCode = 400 }
          else {
            $dir = Join-Path $root 'images\.gallery-data'
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $file = Join-Path $dir "$name.json"
            if (Test-Path -LiteralPath $file) { Copy-Item -LiteralPath $file -Destination "$file.bak" -Force }   # one backup of the last version
            $tmp = "$file.tmp"
            [IO.File]::WriteAllText($tmp, $body, (New-Object Text.UTF8Encoding $false))
            Move-Item -LiteralPath $tmp -Destination $file -Force
            $res.StatusCode = 204
          }
        }
      } else { $res.StatusCode = 405 }
    } elseif ($rel -eq '__id') {
      # lets another start-up of this same copy recognise it (see the top of this file)
      $bytes = [Text.Encoding]::UTF8.GetBytes($myId)
      $res.ContentType = 'text/plain; charset=utf-8'
      $res.AddHeader('Cache-Control', 'no-store')
      $res.ContentLength64 = $bytes.Length
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $path = [IO.Path]::GetFullPath((Join-Path $root $rel))
      if (-not $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $res.StatusCode = 404
      } else {
        $fi = Get-Item -LiteralPath $path
        $ext = $fi.Extension.ToLower()
        if ($types.ContainsKey($ext)) { $res.ContentType = $types[$ext] } else { $res.ContentType = 'application/octet-stream' }
        $res.AddHeader('Accept-Ranges', 'bytes')
        $res.AddHeader('Cache-Control', 'no-cache')   # always serve the latest page and media list
        $len = $fi.Length; $start = 0; $end = $len - 1
        $range = $ctx.Request.Headers['Range']
        if ($range -and $range -match '^bytes=(\d*)-(\d*)$') {
          if ($matches[1] -ne '') {
            $start = [long]$matches[1]
            if ($matches[2] -ne '') { $end = [Math]::Min([long]$matches[2], $len - 1) }
          } elseif ($matches[2] -ne '') {
            $start = [Math]::Max(0, $len - [long]$matches[2])
          }
          $res.StatusCode = 206
          $res.AddHeader('Content-Range', "bytes $start-$end/$len")
        }
        $count = $end - $start + 1
        $res.ContentLength64 = $count
        $fs = [IO.File]::OpenRead($path)
        try {
          [void]$fs.Seek($start, 'Begin')
          $buf = New-Object byte[] 65536
          $remaining = $count
          while ($remaining -gt 0) {
            $n = $fs.Read($buf, 0, [int][Math]::Min($buf.Length, $remaining))
            if ($n -le 0) { break }
            $res.OutputStream.Write($buf, 0, $n)
            $remaining -= $n
          }
        } finally { $fs.Close() }
      }
    }
  } catch {
    # browser cancelled the request (normal when skipping videos) - ignore
  } finally {
    try { $res.Close() } catch {}
  }
}
