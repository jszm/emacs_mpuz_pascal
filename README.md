# emacs_mpuz_pascal

Free Pascal console recreation of GNU Emacs `M-x mpuz`, the multiplication
puzzle where letters stand for digits.

## Build on Windows

This repository is set up for the Lazarus-bundled Free Pascal compiler:

```powershell
.\build.ps1
```

The script expects Lazarus at `C:\lazarus` by default and writes the program
to `bin\mpuz_pascal.exe`. Set `LAZARUS_HOME` to use another Lazarus installation.
The Windows executable `bin\mpuz_pascal.exe` is intentionally tracked so the
repository includes a ready-to-run binary.

The Lazarus project file can also be built with:

```powershell
C:\lazarus\lazbuild.exe .\mpuz_pascal.lpi
```

You can also compile directly:

```powershell
C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe -Mobjfpc -Scghi -O1 -obin\mpuz_pascal.exe src\mpuz.lpr
```

## Play

```powershell
.\bin\mpuz_pascal.exe
```

Use guesses such as `A3`, `A=3`, or `A 3`.

Commands:

- `help` or `?`
- `solution`: reveal the whole puzzle
- `solution 1` through `solution 5`: reveal one row only
  - `1`: multiplicand
  - `2`: multiplier
  - `3`: first partial product
  - `4`: second partial product
  - `5`: final product
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
auto-solve behavior, statistics updates, and console command transcripts.

To compare deterministic snapshots against GNU Emacs `lisp/play/mpuz.el`, run:

```powershell
.\parity.ps1
```

The parity runner expects batch Emacs at
`C:\localdata\tools\emacs-30.2\bin\emacs.exe` by default. Set `EMACS_EXE` and
`EMACS_MPUZ_EL` to use a different Emacs executable or `mpuz.el` source file.

## Notes

The puzzle generation, digit-to-letter permutation, board coordinates,
error counter, completion statistics, and trivial-row solving logic follow the
GNU Emacs `lisp/play/mpuz.el` implementation.

## License

GPL-3.0-or-later. This is a Pascal recreation derived from GNU Emacs
`lisp/play/mpuz.el`.
