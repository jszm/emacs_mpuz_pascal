$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$LazarusRoot = if ($env:LAZARUS_HOME) { $env:LAZARUS_HOME } else { 'C:\lazarus' }
$Fpc = Join-Path $LazarusRoot 'fpc\3.2.2\bin\x86_64-win64\fpc.exe'
$EmacsExe = if ($env:EMACS_EXE) {
    $env:EMACS_EXE
} else {
    'C:\localdata\tools\emacs-30.2\bin\emacs.exe'
}
$EmacsMpuz = if ($env:EMACS_MPUZ_EL) {
    $env:EMACS_MPUZ_EL
} else {
    'C:\localdata\tools\emacs-30.2\share\emacs\30.2\lisp\play\mpuz.el'
}
$OutDir = Join-Path $Root 'bin'
$UnitDir = Join-Path $Root 'lib\parity'
$PascalExe = Join-Path $OutDir 'mpuz_parity_pascal.exe'
$PascalOut = Join-Path $OutDir 'mpuz_parity_pascal.txt'
$EmacsOut = Join-Path $OutDir 'mpuz_parity_emacs.txt'

if (-not (Test-Path -LiteralPath $Fpc)) {
    throw "FPC was not found at $Fpc"
}
if (-not (Test-Path -LiteralPath $EmacsExe)) {
    throw "Emacs was not found at $EmacsExe"
}
if (-not (Test-Path -LiteralPath $EmacsMpuz)) {
    throw "mpuz.el was not found at $EmacsMpuz"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $UnitDir | Out-Null

& $Fpc `
    -Mobjfpc `
    -Scghi `
    -O1 `
    "-Fu$(Join-Path $Root 'src')" `
    "-FU$UnitDir" `
    "-o$PascalExe" `
    (Join-Path $Root 'tests\mpuz_parity_pascal.lpr')

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $PascalExe | Set-Content -LiteralPath $PascalOut -Encoding utf8
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $EmacsExe --batch -Q -l $EmacsMpuz -l (Join-Path $Root 'tests\mpuz_parity_emacs.el') |
    Set-Content -LiteralPath $EmacsOut -Encoding utf8
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$pascalLines = Get-Content -LiteralPath $PascalOut
$emacsLines = Get-Content -LiteralPath $EmacsOut
$max = [Math]::Max($pascalLines.Count, $emacsLines.Count)

for ($i = 0; $i -lt $max; $i++) {
    $pascalLine = if ($i -lt $pascalLines.Count) { $pascalLines[$i] } else { '<missing>' }
    $emacsLine = if ($i -lt $emacsLines.Count) { $emacsLines[$i] } else { '<missing>' }
    if ($pascalLine -ne $emacsLine) {
        $lineNumber = $i + 1
        Write-Host "Parity mismatch at line $lineNumber"
        Write-Host "Pascal: $pascalLine"
        Write-Host "Emacs : $emacsLine"
        Write-Host "Full outputs:"
        Write-Host "  $PascalOut"
        Write-Host "  $EmacsOut"
        exit 1
    }
}

Write-Host "Parity check passed: $($pascalLines.Count) snapshot lines matched."
