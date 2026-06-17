$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Fpc = 'C:\localdata\dev\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe'
$OutDir = Join-Path $Root 'bin'
$UnitDir = Join-Path $Root 'lib'
$Target = Join-Path $OutDir 'mpuz_pascal.exe'

if (-not (Test-Path -LiteralPath $Fpc)) {
    throw "FPC was not found at $Fpc"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $UnitDir | Out-Null

$running = Get-Process -Name 'mpuz_pascal' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $Target }
if ($running) {
    $running | Stop-Process -Force
    Start-Sleep -Milliseconds 200
}

$buildStartedAt = Get-Date

& $Fpc `
    -Mobjfpc `
    -Scghi `
    -O1 `
    "-FU$UnitDir" `
    "-o$Target" `
    (Join-Path $Root 'src\mpuz.lpr')

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $Target)) {
    throw "Build did not produce $Target"
}

if ((Get-Item -LiteralPath $Target).LastWriteTime -lt $buildStartedAt.AddSeconds(-1)) {
    throw "Build did not refresh $Target"
}

Write-Host "Built $Target"
