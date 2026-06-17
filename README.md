# emacs_mpuz_pascal

Free Pascal console recreation of GNU Emacs `M-x mpuz`, the multiplication
puzzle where letters stand for digits.

## Build on Windows

This repository is set up for the Lazarus-bundled Free Pascal compiler:

```powershell
.\build.ps1
```

The script expects Lazarus at `C:\localdata\dev\lazarus` and writes the program
to `bin\mpuz_pascal.exe`.
The Windows executable `bin\mpuz_pascal.exe` is intentionally tracked so the
repository includes a ready-to-run binary.

The Lazarus project file can also be built with:

```powershell
C:\localdata\dev\lazarus\lazbuild.exe .\mpuz_pascal.lpi
```

You can also compile directly:

```powershell
C:\localdata\dev\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe -Mobjfpc -Scghi -O1 -obin\mpuz_pascal.exe src\mpuz.lpr
```

## Play

```powershell
.\bin\mpuz_pascal.exe
```

Use guesses such as `A3`, `A=3`, or `A 3`.

Commands:

- `help` or `?`
- `solution`
- `solution 1` through `solution 5`
- `new`
- `abort`
- `quit`

## Test

```powershell
.\test.ps1
```

The regression test executable uses fixed random seeds and checks the
digit/letter permutation, multiplication identities, board coordinates,
rendered board lines, guess parsing, correct and incorrect guess handling,
auto-solve behavior, and statistics updates.

## Notes

The puzzle generation, digit-to-letter permutation, board coordinates,
error counter, completion statistics, and trivial-row solving logic follow the
GNU Emacs `lisp/play/mpuz.el` implementation.

## License

GPL-3.0-or-later. This is a Pascal recreation derived from GNU Emacs
`lisp/play/mpuz.el`.
