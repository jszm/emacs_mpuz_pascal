program MpuzParityPascal;

{$mode objfpc}{$H+}

{
  Emits deterministic Pascal mpuz snapshots for comparison with GNU Emacs
  lisp/play/mpuz.el.
}

uses
  SysUtils,
  mpuz_core;

const
  MappingA: array[0..DigitCount - 1] of Integer = (9, 1, 5, 0, 8, 2, 7, 3, 6, 4);
  MappingB: array[0..DigitCount - 1] of Integer = (3, 7, 2, 9, 0, 6, 1, 8, 4, 5);
  MappingC: array[0..DigitCount - 1] of Integer = (0, 2, 4, 6, 8, 1, 3, 5, 7, 9);

  DrawStreamA: array[0..14] of Integer = (2, 5, 1, 7, 0, 3, 1, 0, 1, 0, 233, 1, 0, 0, 2);
  DrawStreamB: array[0..14] of Integer = (9, 0, 8, 1, 6, 2, 4, 1, 0, 0, 874, 6, 4, 4, 5);

var
  ActiveDraws: ^Integer;
  ActiveDrawCount: Integer = 0;
  ActiveDrawIndex: Integer = 0;

function DrawProvider(const Limit: Integer): Integer;
begin
  if ActiveDrawIndex >= ActiveDrawCount then
    raise Exception.Create('parity draw stream exhausted');

  Result := ActiveDraws[ActiveDrawIndex] mod Limit;
  Inc(ActiveDrawIndex);
end;

procedure AddSquareDirect(const Digit, Row, Col: Integer);
var
  Count: Integer;
begin
  Count := Game.Board[Digit].Count;
  Game.Board[Digit].Items[Count].Row := Row;
  Game.Board[Digit].Items[Count].Col := Col;
  Inc(Game.Board[Digit].Count);
end;

procedure PutNumberDirect(Number, Row: Integer; const Columns: array of Integer);
var
  I: Integer;
  Digit: Integer;
begin
  for I := Low(Columns) to High(Columns) do
  begin
    Digit := Number mod 10;
    Number := Number div 10;
    AddSquareDirect(Digit, Row, Columns[I]);
  end;
end;

procedure PutFixtureNumbers(const A, B1, B2: Integer);
var
  C: Integer;
  D: Integer;
  E: Integer;
begin
  C := A * B2;
  D := A * B1;
  E := C + (D * 10);

  PutNumberDirect(A, 2, [9, 7, 5]);
  PutNumberDirect((B1 * 10) + B2, 4, [9, 7]);
  PutNumberDirect(C, 6, [9, 7, 5, 3]);
  PutNumberDirect(D, 8, [7, 5, 3, 1]);
  PutNumberDirect(E, 10, [9, 7, 5, 3, 1]);
end;

procedure ResetFixture(const Mapping: array of Integer; const A, B1, B2: Integer);
var
  Digit: Integer;
begin
  InitGameWithSeed(1);
  ResetRandomIntProvider;
  Game.InProgress := True;
  Game.SolveWhenTrivial := True;
  Game.AllowDoubleMultiplicator := False;
  Game.NbErrors := 0;
  Game.NbCompletedGames := 0;
  Game.NbCumulatedErrors := 0;

  ClearBoard;
  ClearDigitState;

  for Digit := 0 to DigitCount - 1 do
  begin
    Game.DigitToLetter[Digit] := Mapping[Digit];
    Game.LetterToDigit[Mapping[Digit]] := Digit;
  end;

  PutFixtureNumbers(A, B1, B2);
end;

procedure ResetFixtureA;
begin
  ResetFixture(MappingA, 358, 4, 7);
end;

function BoolText(const Value: Boolean): string;
begin
  if Value then
    Result := 't'
  else
    Result := 'nil';
end;

function FlagsText(const Flags: array of Boolean): string;
var
  Digit: Integer;
begin
  Result := '';
  for Digit := Low(Flags) to High(Flags) do
    Result := Result + BoolText(Flags[Digit]);
end;

function MappingText: string;
var
  Digit: Integer;
begin
  Result := '';
  for Digit := 0 to DigitCount - 1 do
    Result := Result + Chr(Ord('0') + Game.DigitToLetter[Digit]);
end;

function DigitAtCell(const Row, Col: Integer): Integer;
var
  Digit: Integer;
begin
  for Digit := 0 to DigitCount - 1 do
    if DigitAppears(Digit, Row, Col) then
      Exit(Digit);
  Result := -1;
end;

function BoardText: string;
const
  Rows: array[0..4] of Integer = (2, 4, 6, 8, 10);
  Cols: array[0..4] of Integer = (1, 3, 5, 7, 9);
var
  R: Integer;
  C: Integer;
  Digit: Integer;
begin
  Result := '';
  for R := Low(Rows) to High(Rows) do
    for C := Low(Cols) to High(Cols) do
    begin
      Digit := DigitAtCell(Rows[R], Cols[C]);
      if Digit >= 0 then
      begin
        if Result <> '' then
          Result := Result + ',';
        Result := Result + Format('%d:%d=%d', [Rows[R], Cols[C], Digit]);
      end;
    end;
end;

function GuessResultText(const ResultCode: TGuessResult): string;
begin
  case ResultCode of
    grNoGame: Result := 'no-game';
    grBadInput: Result := 'bad-input';
    grAlreadySolved: Result := 'already-solved';
    grDoesNotAppear: Result := 'does-not-appear';
    grDigitAlreadyPlaced: Result := 'digit-already-placed';
    grCorrect: Result := 'correct';
    grIncorrect: Result := 'incorrect';
  end;
end;

procedure EmitScreen;
var
  Lines: TBoardLines;
  I: Integer;
begin
  Lines := BuildBoardLines;
  for I := Low(Lines) to High(Lines) do
    WriteLn('screen|', I, '|', Lines[I]);
end;

procedure EmitState(const Name: string);
begin
  WriteLn('case|', Name);
  WriteLn('state|in-progress|', BoolText(Game.InProgress));
  WriteLn('state|errors|', Game.NbErrors);
  WriteLn('state|completed|', Game.NbCompletedGames);
  WriteLn('state|cumulated|', Game.NbCumulatedErrors);
  WriteLn('state|found|', FlagsText(Game.FoundDigits));
  WriteLn('state|trivial|', FlagsText(Game.TrivialDigits));
  WriteLn('state|average|', AverageErrorsText);
  WriteLn('state|mapping|', MappingText);
  WriteLn('state|board|', BoardText);
  EmitScreen;
end;

function LetterForDigit(const Digit: Integer): Char;
begin
  Result := Chr(Ord('A') + Game.DigitToLetter[Digit]);
end;

procedure EmitTry(const Name: string; const LetterChar, DigitChar: Char);
var
  CorrectDigit: Integer;
  ResultCode: TGuessResult;
begin
  ResultCode := TryProposal(LetterChar, DigitChar, CorrectDigit);
  WriteLn('op|', Name, '|', GuessResultText(ResultCode), '|correct-digit=', CorrectDigit);
  EmitState(Name);
end;

procedure EmitCheckAllSolved(const Name: string);
begin
  WriteLn('op|', Name, '|check-all-solved=', BoolText(CheckAllSolved));
  EmitState(Name);
end;

procedure MarkFound(const Digits: array of Integer);
var
  I: Integer;
begin
  for I := Low(Digits) to High(Digits) do
    Game.FoundDigits[Digits[I]] := True;
end;

procedure RunBranchParity;
begin
  ResetFixtureA;
  EmitState('fixture-a-fresh');
  EmitTry('try-incorrect', LetterForDigit(3), '4');
  EmitTry('try-correct', LetterForDigit(3), '3');
  EmitTry('try-already-solved', LetterForDigit(3), '3');
  EmitTry('try-digit-already-placed', LetterForDigit(5), '3');

  ResetFixtureA;
  EmitTry('try-does-not-appear', LetterForDigit(9), '9');
  EmitTry('try-bad-digit', LetterForDigit(3), 'X');
end;

procedure RunRowSolveParity;
begin
  ResetFixtureA;
  Solve(2, -1);
  EmitState('solve-row-2');

  ResetFixtureA;
  Solve(4, -1);
  EmitState('solve-row-4');

  ResetFixtureA;
  Solve(4, 7);
  EmitState('solve-row-4-col-7');

  ResetFixtureA;
  Solve(4, 9);
  EmitState('solve-row-4-col-9');

  ResetFixtureA;
  Solve(6, -1);
  EmitState('solve-row-6');

  ResetFixtureA;
  Solve(6, 9);
  EmitState('solve-row-6-col-9');

  ResetFixtureA;
  Solve(8, -1);
  EmitState('solve-row-8');

  ResetFixtureA;
  Solve(8, 7);
  EmitState('solve-row-8-col-7');

  ResetFixtureA;
  Solve(10, -1);
  EmitState('solve-row-10');

  ResetFixtureA;
  Solve;
  CheckAllSolved;
  CloseGameCore;
  EmitState('solve-full-close');
end;

procedure RunAutoSolveParity;
begin
  ResetFixtureA;
  MarkFound([4, 7]);
  EmitCheckAllSolved('autosolve-b1-b2');

  ResetFixtureA;
  MarkFound([1, 2, 3, 4]);
  EmitCheckAllSolved('autosolve-d-to-e');

  ResetFixtureA;
  MarkFound([1, 2, 3, 4, 6, 8]);
  EmitCheckAllSolved('autosolve-e-and-d-to-c');

  ResetFixtureA;
  MarkFound([0, 2, 3, 5, 6, 8]);
  EmitCheckAllSolved('autosolve-a-c-to-b2');

  ResetFixtureA;
  MarkFound([1, 2, 3, 4, 5, 8]);
  EmitCheckAllSolved('autosolve-a-d-to-b1');

  ResetFixtureA;
  MarkFound([0, 2, 5, 6, 7]);
  EmitCheckAllSolved('autosolve-b2-c-to-a');

  ResetFixtureA;
  Game.SolveWhenTrivial := False;
  MarkFound([4, 7]);
  EmitCheckAllSolved('autosolve-disabled-b1-b2');
end;

procedure RunFixtureParity;
begin
  ResetFixture(MappingB, 125, 9, 8);
  EmitState('fixture-b-zeros');

  ResetFixture(MappingC, 987, 6, 5);
  EmitState('fixture-c-repeated-digits');
end;

procedure RunRandomParity(const Name: string; const Draws: array of Integer;
  const AllowDouble: Boolean);
begin
  InitGameWithSeed(1);
  ActiveDraws := @Draws[0];
  ActiveDrawCount := Length(Draws);
  ActiveDrawIndex := 0;
  SetRandomIntProvider(@DrawProvider);
  Game.AllowDoubleMultiplicator := AllowDouble;
  Game.InProgress := True;
  ClearDigitState;
  RandomPuzzle;
  ResetRandomIntProvider;
  WriteLn('op|', Name, '|draws-used=', ActiveDrawIndex);
  EmitState(Name);
end;

procedure RunRandomGenerationParity;
begin
  RunRandomParity('random-draws-no-double-with-retry', DrawStreamA, False);
  RunRandomParity('random-draws-allow-double', DrawStreamB, True);
end;

begin
  RunBranchParity;
  RunRowSolveParity;
  RunAutoSolveParity;
  RunFixtureParity;
  RunRandomGenerationParity;
end.
