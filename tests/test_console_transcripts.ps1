param(
    [string] $Exe
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
if (-not $Exe) {
    $Exe = Join-Path $Root 'bin\mpuz_pascal.exe'
}

if (-not (Test-Path -LiteralPath $Exe)) {
    throw "mpuz executable was not found at $Exe"
}

$script:Checks = 0

function Invoke-MpuzTranscript {
    param(
        [string] $InputText
    )

    $inputFile = [System.IO.Path]::GetTempFileName()
    $outputFile = [System.IO.Path]::GetTempFileName()
    $errorFile = [System.IO.Path]::GetTempFileName()

    try {
        [System.IO.File]::WriteAllText($inputFile, $InputText, [System.Text.Encoding]::ASCII)
        $command = '"{0}" < "{1}" > "{2}" 2> "{3}"' -f $Exe, $inputFile, $outputFile, $errorFile

        Push-Location $Root
        try {
            & cmd.exe /d /c $command
            $exitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        [pscustomobject]@{
            ExitCode = $exitCode
            Output = [System.IO.File]::ReadAllText($outputFile, [System.Text.Encoding]::Default)
            ErrorOutput = [System.IO.File]::ReadAllText($errorFile, [System.Text.Encoding]::Default)
        }
    } finally {
        Remove-Item -LiteralPath $inputFile, $outputFile, $errorFile -Force -ErrorAction SilentlyContinue
    }
}

function Join-InputLines {
    param(
        [string[]] $Lines
    )

    if ($Lines.Count -eq 0) {
        return ''
    }

    return ($Lines -join "`n") + "`n"
}

function Assert-True {
    param(
        [bool] $Condition,
        [string] $Name
    )

    $script:Checks++
    if (-not $Condition) {
        throw "FAIL: $Name"
    }
}

function Assert-ExitOk {
    param(
        [pscustomobject] $Result,
        [string] $Name
    )

    Assert-True ($Result.ExitCode -eq 0) "$Name exit code"
    Assert-True ($Result.ErrorOutput -eq '') "$Name stderr is empty"
}

function Assert-Contains {
    param(
        [string] $Text,
        [string] $Needle,
        [string] $Name
    )

    Assert-True ($Text.Contains($Needle)) $Name
}

function Assert-NotContains {
    param(
        [string] $Text,
        [string] $Needle,
        [string] $Name
    )

    Assert-True (-not $Text.Contains($Needle)) $Name
}

function Assert-Matches {
    param(
        [string] $Text,
        [string] $Pattern,
        [string] $Name
    )

    Assert-True ([regex]::IsMatch($Text, $Pattern)) $Name
}

function Count-Occurrences {
    param(
        [string] $Text,
        [string] $Needle
    )

    return [regex]::Matches($Text, [regex]::Escape($Needle)).Count
}

$result = Invoke-MpuzTranscript (Join-InputLines @('quit'))
Assert-ExitOk $result 'quit transcript'
Assert-Contains $result.Output 'Here we go...' 'quit starts a game'
Assert-Matches $result.Output "\r?\n\r?\nYour try\?\r?\n> $" 'blank line precedes first prompt'

$result = Invoke-MpuzTranscript (Join-InputLines @('help', 'quit'))
Assert-ExitOk $result 'help transcript'
Assert-Contains $result.Output '> Multiplication puzzle.' 'help prints after prompt'
Assert-Contains $result.Output 'Commands: help, solution [1-5], new, abort, quit.' 'help lists commands'

$result = Invoke-MpuzTranscript (Join-InputLines @('solution 6', 'quit'))
Assert-ExitOk $result 'bad solution transcript'
Assert-Contains $result.Output 'Use solution or solution N, where N is 1..5.' 'bad solution is rejected'

$result = Invoke-MpuzTranscript (Join-InputLines @('  SoLuTiOn    1  ', 'quit'))
Assert-ExitOk $result 'whitespace solution transcript'
Assert-NotContains $result.Output 'Use solution or solution N' 'whitespace solution command is normalized'
Assert-NotContains $result.Output 'Puzzle solved with' 'single-row solution does not close game'

$result = Invoke-MpuzTranscript (Join-InputLines @('A=Q', 'quit'))
Assert-ExitOk $result 'bad guess transcript'
Assert-Contains $result.Output 'Enter a letter A-J followed by a digit' 'bad guess is rejected'

$result = Invoke-MpuzTranscript (Join-InputLines @('new', 'quit'))
Assert-ExitOk $result 'new transcript'
Assert-True ((Count-Occurrences $result.Output 'Here we go...') -eq 2) 'new starts exactly one replacement game'

$result = Invoke-MpuzTranscript (Join-InputLines @('abort', 'n', 'quit'))
Assert-ExitOk $result 'abort no transcript'
Assert-Contains $result.Output 'Abort game? ' 'abort asks for confirmation'
Assert-Contains $result.Output 'Your try?' 'declined abort returns to prompt'
Assert-NotContains $result.Output 'Mult Puzzle aborted.' 'declined abort does not abort'

$result = Invoke-MpuzTranscript (Join-InputLines @('abort', 'y', 'solution', 'n', 'quit'))
Assert-ExitOk $result 'abort yes no-game transcript'
Assert-Contains $result.Output 'Mult Puzzle aborted.' 'confirmed abort clears game'
Assert-Contains $result.Output 'Start a new game? ' 'solution with no game asks to start'
Assert-Contains $result.Output "OK. I won't." 'declined no-game start is reported'
Assert-True ((Count-Occurrences $result.Output 'Here we go...') -eq 1) 'declined no-game start does not create another game'

$result = Invoke-MpuzTranscript (Join-InputLines @('solution'))
Assert-ExitOk $result 'solution EOF transcript'
Assert-Contains $result.Output 'Puzzle solved with 0 errors. That''s perfect!' 'solution closes solved game'
Assert-Contains $result.Output 'Start a new game? ' 'solution asks for next game'
Assert-Contains $result.Output 'Good Bye!' 'EOF at solved prompt declines next game'
Assert-True ((Count-Occurrences $result.Output 'Here we go...') -eq 1) 'EOF at solved prompt does not start another game'

$result = Invoke-MpuzTranscript ''
Assert-ExitOk $result 'empty EOF transcript'
Assert-Contains $result.Output 'Your try?' 'empty input still shows initial prompt'
Assert-NotContains $result.Output 'Start a new game? ' 'empty EOF does not ask extra prompt'

Write-Host "$script:Checks console transcript checks passed."
