$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$LazarusRoot = if ($env:LAZARUS_HOME) { $env:LAZARUS_HOME } else { 'C:\lazarus' }
$Fpc = Join-Path $LazarusRoot 'fpc\3.2.2\bin\x86_64-win64\fpc.exe'
$OutDir = Join-Path $Root 'bin'
$UnitDir = Join-Path $Root 'lib\tests'

if (-not (Test-Path -LiteralPath $Fpc)) {
    throw "FPC was not found at $Fpc"
}

& (Join-Path $Root 'build.ps1')

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $UnitDir | Out-Null

& $Fpc `
    -Mobjfpc `
    -Scghi `
    -O1 `
    "-Fu$(Join-Path $Root 'src')" `
    "-FU$UnitDir" `
    "-o$(Join-Path $OutDir 'test_mpuz.exe')" `
    (Join-Path $Root 'tests\test_mpuz.lpr')

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& (Join-Path $OutDir 'test_mpuz.exe')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& (Join-Path $Root 'tests\test_console_transcripts.ps1') `
    -Exe (Join-Path $OutDir 'mpuz_pascal.exe')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
