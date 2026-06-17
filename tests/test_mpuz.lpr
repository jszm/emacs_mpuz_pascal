program TestMpuz;

{$mode objfpc}{$H+}

{
  Regression tests for the Pascal recreation of GNU Emacs mpuz.el.
  Copyright (C) 2026

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
}

uses
  SysUtils,
  mpuz_core;

var
  Checks: Integer = 0;
  Failures: Integer = 0;

procedure Check(const Condition: Boolean; const Name: string);
begin
  Inc(Checks);
  if not Condition then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name);
  end;
end;

procedure CheckEqualsInt(const Expected, Actual: Integer; const Name: string);
begin
  Check(Expected = Actual, Format('%s expected=%d actual=%d', [Name, Expected, Actual]));
end;

procedure CheckEqualsStr(const Expected, Actual, Name: string);
begin
  Check(Expected = Actual, Format('%s expected="%s" actual="%s"', [Name, Expected, Actual]));
end;

procedure CheckEqualsChar(const Expected, Actual: Char; const Name: string);
begin
  Check(Expected = Actual, Format('%s expected="%s" actual="%s"', [Name, Expected, Actual]));
end;

procedure CheckEqualsGuess(const Expected, Actual: TGuessResult; const Name: string);
begin
  Check(Expected = Actual, Format('%s expected=%d actual=%d', [Name, Ord(Expected), Ord(Actual)]));
end;

function TotalSquares: Integer;
var
  Digit: Integer;
begin
  Result := 0;
  for Digit := 0 to DigitCount - 1 do
    Inc(Result, Game.Board[Digit].Count);
end;

function DigitAt(const Row, Col: Integer): Integer;
var
  Digit: Integer;
  Matches: Integer;
begin
  Result := -1;
  Matches := 0;
  for Digit := 0 to DigitCount - 1 do
    if DigitAppears(Digit, Row, Col) then
    begin
      Result := Digit;
      Inc(Matches);
    end;

  CheckEqualsInt(1, Matches, Format('one digit at row %d col %d', [Row, Col]));
end;

function NumberAt(const Row: Integer; const Columns: array of Integer): Integer;
var
  I: Integer;
  Digit: Integer;
begin
  Result := 0;
  for I := Low(Columns) to High(Columns) do
  begin
    Digit := DigitAt(Row, Columns[I]);
    Result := (Result * 10) + Digit;
  end;
end;

function FirstAppearingDigitExcept(const ExcludedDigit: Integer): Integer;
var
  Digit: Integer;
begin
  for Digit := 0 to DigitCount - 1 do
    if (Digit <> ExcludedDigit) and (Game.Board[Digit].Count > 0) then
      Exit(Digit);
  Result := -1;
end;

procedure TestPermutation;
var
  Digit: Integer;
  SeenLetters: array[0..DigitCount - 1] of Boolean;
begin
  FillChar(SeenLetters, SizeOf(SeenLetters), 0);
  InitGameWithSeed(1001);
  StartNewGameCore;

  for Digit := 0 to DigitCount - 1 do
  begin
    Check((Game.DigitToLetter[Digit] >= 0) and (Game.DigitToLetter[Digit] < DigitCount),
      'digit-to-letter value in range');
    Check(not SeenLetters[Game.DigitToLetter[Digit]], 'digit-to-letter is unique');
    SeenLetters[Game.DigitToLetter[Digit]] := True;
    CheckEqualsInt(Digit, Game.LetterToDigit[Game.DigitToLetter[Digit]],
      'letter-to-digit inverse');
  end;
end;

procedure TestPuzzleArithmeticAndCoordinates;
var
  A: Integer;
  B: Integer;
  B1: Integer;
  B2: Integer;
  C: Integer;
  D: Integer;
  E: Integer;
begin
  InitGameWithSeed(2002);
  StartNewGameCore;

  A := NumberAt(2, [5, 7, 9]);
  B := NumberAt(4, [7, 9]);
  B1 := B div 10;
  B2 := B mod 10;
  C := NumberAt(6, [3, 5, 7, 9]);
  D := NumberAt(8, [1, 3, 5, 7]);
  E := NumberAt(10, [1, 3, 5, 7, 9]);

  Check((A >= 125) and (A <= 999), 'multiplicand range follows mpuz.el default');
  Check((B1 >= 1) and (B1 <= 9), 'first multiplier digit range');
  Check((B2 >= 1) and (B2 <= 9), 'second multiplier digit range');
  Check(B1 <> B2, 'double multiplicator disabled by default');
  CheckEqualsInt(A * B2, C, 'first partial product');
  CheckEqualsInt(A * B1, D, 'second partial product');
  CheckEqualsInt(C + (D * 10), E, 'final product');
  CheckEqualsInt(18, TotalSquares, 'board square count');
end;

procedure TestBoardRendering;
var
  Lines: TBoardLines;
  Digit: Integer;
begin
  InitGameWithSeed(3003);
  StartNewGameCore;
  Lines := BuildBoardLines;

  CheckEqualsStr('   -------', Lines[5], 'first separator line');
  Check(Pos('Number of errors (this game): 0', Lines[3]) > 0, 'error counter rendered');
  Check(Pos('Number of completed games: 0', Lines[7]) > 0, 'completed counter rendered');
  Check(Pos('Average number of errors: 0.00', Lines[9]) > 0, 'average rendered');

  Digit := DigitAt(2, 5);
  Check((Lines[2][6] >= 'A') and (Lines[2][6] <= 'J'), 'unsolved board uses letters');
  CheckEqualsChar(CharForDigit(Digit), Lines[2][6], 'rendered letter matches digit mapping');

  Solve;
  Lines := BuildBoardLines;
  Digit := DigitAt(2, 5);
  CheckEqualsChar(Chr(Ord('0') + Digit), Lines[2][6], 'solved board uses digits');
end;

procedure TestGuessParsing;
var
  LetterChar: Char;
  DigitChar: Char;
begin
  Check(ExtractGuess('a=3', LetterChar, DigitChar), 'lowercase equals syntax parsed');
  CheckEqualsChar('A', LetterChar, 'lowercase letter normalized');
  CheckEqualsChar('3', DigitChar, 'equals digit parsed');

  Check(ExtractGuess('B 7', LetterChar, DigitChar), 'space syntax parsed');
  CheckEqualsChar('B', LetterChar, 'space letter parsed');
  CheckEqualsChar('7', DigitChar, 'space digit parsed');

  Check(not ExtractGuess('not-a-guess', LetterChar, DigitChar), 'bad guess rejected');
end;

procedure TestGuessFlow;
var
  CorrectDigit: Integer;
  OtherDigit: Integer;
  LetterChar: Char;
  OtherLetterChar: Char;
  DigitChar: Char;
  WrongDigitChar: Char;
  ParsedLetter: Char;
  ParsedDigit: Char;
  ReportedCorrectDigit: Integer;
begin
  InitGameWithSeed(4004);
  StartNewGameCore;
  CorrectDigit := FirstAppearingDigitExcept(-1);
  OtherDigit := FirstAppearingDigitExcept(CorrectDigit);

  LetterChar := Chr(Ord('A') + Game.DigitToLetter[CorrectDigit]);
  OtherLetterChar := Chr(Ord('A') + Game.DigitToLetter[OtherDigit]);
  DigitChar := Chr(Ord('0') + CorrectDigit);
  WrongDigitChar := Chr(Ord('0') + ((CorrectDigit + 1) mod DigitCount));

  CheckEqualsGuess(grBadInput, TryGuess('bogus', ParsedLetter, ParsedDigit,
    ReportedCorrectDigit), 'bad input result');
  CheckEqualsInt(0, Game.NbErrors, 'bad input does not count as error');

  CheckEqualsGuess(grIncorrect, TryGuess(LetterChar + WrongDigitChar, ParsedLetter,
    ParsedDigit, ReportedCorrectDigit), 'incorrect guess result');
  CheckEqualsInt(1, Game.NbErrors, 'incorrect guess increments error count');

  CheckEqualsGuess(grCorrect, TryGuess(LowerCase(LetterChar) + DigitChar,
    ParsedLetter, ParsedDigit, ReportedCorrectDigit), 'correct lowercase guess result');
  Check(Game.FoundDigits[CorrectDigit], 'correct guess marks digit found');
  CheckEqualsInt(CorrectDigit, ReportedCorrectDigit, 'correct digit reported');

  CheckEqualsGuess(grAlreadySolved, TryGuess(LetterChar + DigitChar, ParsedLetter,
    ParsedDigit, ReportedCorrectDigit), 'same letter reports already solved');

  CheckEqualsGuess(grDigitAlreadyPlaced, TryGuess(OtherLetterChar + DigitChar,
    ParsedLetter, ParsedDigit, ReportedCorrectDigit), 'known digit cannot be reused');
end;

procedure TestSolvingAndStatistics;
begin
  InitGameWithSeed(5005);
  StartNewGameCore;
  Game.NbErrors := 2;

  Solve;
  Check(CheckAllSolved, 'full solve marks puzzle solved');
  CloseGameCore;

  Check(not Game.InProgress, 'close game clears in-progress flag');
  CheckEqualsInt(1, Game.NbCompletedGames, 'completed game count updated');
  CheckEqualsInt(2, Game.NbCumulatedErrors, 'cumulated errors updated');
  CheckEqualsStr('2.00', AverageErrorsText, 'average errors updated');
  CheckEqualsStr('good.', ScoreText, 'score text for two errors');

  StartNewGameCore;
  CheckEqualsInt(1, Game.NbCompletedGames, 'new game preserves completed count');
  CheckEqualsInt(0, Game.NbErrors, 'new game resets current errors');
end;

procedure TestPartialSolve;
begin
  InitGameWithSeed(6006);
  StartNewGameCore;

  Solve(2, -1);
  Check(CheckAllSolved(2, -1), 'row solve solves multiplicand row');
  Check(not CheckAllSolved(4, 7), 'unrelated multiplier cell remains unsolved');
end;

begin
  TestPermutation;
  TestPuzzleArithmeticAndCoordinates;
  TestBoardRendering;
  TestGuessParsing;
  TestGuessFlow;
  TestSolvingAndStatistics;
  TestPartialSolve;

  if Failures = 0 then
  begin
    WriteLn(Checks, ' checks passed.');
    Halt(0);
  end;

  WriteLn(Failures, ' failure(s) out of ', Checks, ' checks.');
  Halt(1);
end.
