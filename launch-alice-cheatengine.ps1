# Launch game + attach CheatEngine + load CheatTable
# Launch via Steam (DRM unpacks .bind at runtime),
# wait for the unpacked process, then start CE with autoattach.

$ErrorActionPreference = "Stop"

$cePath    = "C:\Program Files\Cheat Engine\cheatengine-i386.exe"
$ctPath    = "$PSScriptRoot\AliceMadnessReturns.CT"
$steamId   = 19680
$autoSrc   = "$PSScriptRoot\alice-autoattach.lua"
$autoDst   = "C:\Program Files\Cheat Engine\autorun\custom\alice-autoattach.lua"

if (-not (Test-Path $cePath))   { throw "CE not found at $cePath" }
if (-not (Test-Path $ctPath))   { throw "CT not found at $ctPath" }
if (-not (Test-Path $autoSrc))  { throw "autoattach script not found at $autoSrc" }

# Bail if game is already running (avoid double-launch)
$existing = Get-Process AliceMadnessReturns -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "AliceMadnessReturns already running (PID $($existing.Id)) — launching CE"
    Start-Process $cePath
    exit 0
}

# Stamp the CT path into the autoattach script and copy to CE autorun
$luaContent = (Get-Content $autoSrc -Raw -Encoding UTF8) -replace '%%CT_PATH%%', ($ctPath -replace '\\', '\\')
[System.IO.File]::WriteAllText($autoDst, $luaContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "Installed autoattach -> $autoDst"

Write-Host "Launching game via Steam ($steamId)..."
Start-Process "steam://rungameid/$steamId"

# Poll for the process. Steam DRM unpack typically 2-10s.
$proc = $null
$start = Get-Date
while (-not $proc) {
    Start-Sleep -Milliseconds 300
    $proc = Get-Process AliceMadnessReturns -ErrorAction SilentlyContinue
    if (((Get-Date) - $start).TotalSeconds -gt 60) {
        throw "Timed out waiting for AliceMadnessReturns.exe after 60s"
    }
}
Write-Host "Game PID $($proc.Id) up after $(((Get-Date)-$start).TotalSeconds.ToString('F1'))s — launching CE"

Start-Process $cePath
