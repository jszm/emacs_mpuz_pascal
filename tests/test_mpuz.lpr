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

function FirstMissingDigit: Integer;
var
  Digit: Integer;
begin
  for Digit := 0 to DigitCount - 1 do
    if Game.Board[Digit].Count = 0 then
      Exit(Digit);
  Result := -1;
end;

function NextFuzz(var State: Int64; const Limit: Integer): Integer;
begin
  State := (State * 48271) mod 2147483647;
  Result := State mod Limit;
end;

function SolvedDigitCount: Integer;
var
  Digit: Integer;
begin
  Result := 0;
  for Digit := 0 to DigitCount - 1 do
    if DigitSolved(Digit) then
      Inc(Result);
end;

function DigitAtRaw(const Row, Col: Integer; out Matches: Integer): Integer;
var
  Digit: Integer;
begin
  Result := -1;
  Matches := 0;
  for Digit := 0 to DigitCount - 1 do
    if DigitAppears(Digit, Row, Col) then
    begin
      Result := Digit;
      Inc(Matches);
    end;
end;

function NumberAtRaw(const Row: Integer; const Columns: array of Integer;
  out Valid: Boolean): Integer;
var
  I: Integer;
  Digit: Integer;
  Matches: Integer;
begin
  Result := 0;
  Valid := True;
  for I := Low(Columns) to High(Columns) do
  begin
    Digit := DigitAtRaw(Row, Columns[I], Matches);
    if Matches <> 1 then
      Valid := False;
    Result := (Result * 10) + Digit;
  end;
end;

procedure CheckGameInvariants(const Context: string);
var
  Digit: Integer;
  I: Integer;
  Total: Integer;
  Letter: Integer;
  SeenLetters: array[0..DigitCount - 1] of Boolean;
  Square: TSquare;
  A: Integer;
  B: Integer;
  B1: Integer;
  B2: Integer;
  C: Integer;
  D: Integer;
  E: Integer;
  Valid: Boolean;
begin
  FillChar(SeenLetters, SizeOf(SeenLetters), 0);
  for Digit := 0 to DigitCount - 1 do
  begin
    Letter := Game.DigitToLetter[Digit];
    Check((Letter >= 0) and (Letter < DigitCount),
      Context + ': digit-to-letter in range');
    if (Letter >= 0) and (Letter < DigitCount) then
    begin
      Check(not SeenLetters[Letter], Context + ': digit-to-letter unique');
      SeenLetters[Letter] := True;
      CheckEqualsInt(Digit, Game.LetterToDigit[Letter],
        Context + ': letter-to-digit inverse');
    end;
  end;

  Total := 0;
  for Digit := 0 to DigitCount - 1 do
  begin
    Check((Game.Board[Digit].Count >= 0) and
      (Game.Board[Digit].Count <= MaxSquaresPerDigit),
      Context + ': board count in range');
    Inc(Total, Game.Board[Digit].Count);

    for I := 0 to Game.Board[Digit].Count - 1 do
    begin
      Square := Game.Board[Digit].Items[I];
      Check((Square.Row = 2) or (Square.Row = 4) or (Square.Row = 6) or
        (Square.Row = 8) or (Square.Row = 10),
        Context + ': square row is a puzzle row');
      Check((Square.Col = 1) or (Square.Col = 3) or (Square.Col = 5) or
        (Square.Col = 7) or (Square.Col = 9),
        Context + ': square column is a puzzle column');
    end;
  end;

  Check((Total = 0) or (Total = 18), Context + ': board square total is stable');
  Check(Game.NbErrors >= 0, Context + ': current error count nonnegative');
  Check(Game.NbCompletedGames >= 0, Context + ': completed count nonnegative');
  Check(Game.NbCumulatedErrors >= 0, Context + ': cumulated error count nonnegative');
  if Game.NbCompletedGames = 0 then
    CheckEqualsInt(0, Game.NbCumulatedErrors,
      Context + ': no completed games means no cumulated errors');

  if Total = 18 then
  begin
    A := NumberAtRaw(2, [5, 7, 9], Valid);
    Check(Valid, Context + ': multiplicand cells are unique');
    B := NumberAtRaw(4, [7, 9], Valid);
    Check(Valid, Context + ': multiplier cells are unique');
    C := NumberAtRaw(6, [3, 5, 7, 9], Valid);
    Check(Valid, Context + ': first partial cells are unique');
    D := NumberAtRaw(8, [1, 3, 5, 7], Valid);
    Check(Valid, Context + ': second partial cells are unique');
    E := NumberAtRaw(10, [1, 3, 5, 7, 9], Valid);
    Check(Valid, Context + ': final product cells are unique');

    B1 := B div 10;
    B2 := B mod 10;
    CheckEqualsInt(A * B2, C, Context + ': first partial product invariant');
    CheckEqualsInt(A * B1, D, Context + ': second partial product invariant');
    CheckEqualsInt(C + (D * 10), E, Context + ': final product invariant');
  end;
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
  CheckEqualsInt(18, Pos('Number of errors (this game):', Lines[3]),
    'error label aligned to console stats column');
  CheckEqualsInt(73, Pos(IntToStr(Game.NbErrors), Lines[3]),
    'error counter aligned to console value column');
  CheckEqualsInt(18, Pos('Number of completed games:', Lines[7]),
    'completed label aligned to console stats column');
  CheckEqualsInt(73, Pos(IntToStr(Game.NbCompletedGames), Lines[7]),
    'completed counter aligned to console value column');
  CheckEqualsInt(18, Pos('Average number of errors:', Lines[9]),
    'average label aligned after separator');
  CheckEqualsInt(73, Pos(AverageErrorsText, Lines[9]),
    'average value aligned to console value column');

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

  Check(ExtractGuess('C = 2', LetterChar, DigitChar), 'spaced equals syntax parsed');
  CheckEqualsChar('C', LetterChar, 'spaced equals letter parsed');
  CheckEqualsChar('2', DigitChar, 'spaced equals digit parsed');

  Check(ExtractGuess('D' + #9 + '4', LetterChar, DigitChar), 'tab syntax parsed');
  CheckEqualsChar('D', LetterChar, 'tab letter parsed');
  CheckEqualsChar('4', DigitChar, 'tab digit parsed');

  Check(not ExtractGuess('not-a-guess', LetterChar, DigitChar), 'bad guess rejected');
  Check(not ExtractGuess('solution1', LetterChar, DigitChar),
    'command-like word is not parsed as guess');
  Check(not ExtractGuess('solution 1', LetterChar, DigitChar),
    'command with digit is not parsed as guess');
  Check(not ExtractGuess('quit1', LetterChar, DigitChar),
    'quit with suffix digit is not parsed as guess');
  Check(not ExtractGuess('A-3', LetterChar, DigitChar),
    'unsupported separator is not parsed as guess');
  Check(not ExtractGuess('AB3', LetterChar, DigitChar),
    'extra letter is not parsed as guess');
  Check(not ExtractGuess('A3 later', LetterChar, DigitChar),
    'extra trailing text is not parsed as guess');
  CheckEqualsChar(#0, LetterChar, 'bad guess leaves letter output clear');
  CheckEqualsChar(#0, DigitChar, 'bad guess leaves digit output clear');
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
  MissingDigit: Integer;
  Seed: LongInt;
begin
  InitGameWithSeed(4003);
  CheckEqualsGuess(grNoGame, TryProposal('A', '1', ReportedCorrectDigit),
    'proposal before game reports no game');
  CheckEqualsInt(-1, ReportedCorrectDigit, 'proposal before game leaves no correct digit');

  StartNewGameCore;
  CheckEqualsGuess(grBadInput, TryProposal('K', '1', ReportedCorrectDigit),
    'proposal rejects invalid letter');
  CheckEqualsInt(-1, ReportedCorrectDigit, 'invalid letter leaves no correct digit');
  CheckEqualsGuess(grBadInput, TryProposal('A', 'X', ReportedCorrectDigit),
    'proposal rejects invalid digit');
  CheckEqualsInt(-1, ReportedCorrectDigit, 'invalid digit leaves no correct digit');

  MissingDigit := -1;
  for Seed := 4100 to 4200 do
  begin
    InitGameWithSeed(Seed);
    StartNewGameCore;
    MissingDigit := FirstMissingDigit;
    if MissingDigit <> -1 then
      Break;
  end;
  Check(MissingDigit <> -1, 'test seed with non-appearing digit found');
  if MissingDigit <> -1 then
  begin
    LetterChar := Chr(Ord('A') + Game.DigitToLetter[MissingDigit]);
    DigitChar := Chr(Ord('0') + MissingDigit);
    CheckEqualsGuess(grDoesNotAppear, TryProposal(LetterChar, DigitChar,
      ReportedCorrectDigit), 'direct proposal rejects non-appearing digit');
    Check(not Game.FoundDigits[MissingDigit],
      'direct proposal does not mark non-appearing digit found');
  end;

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

  CloseGameCore;
  CheckEqualsInt(1, Game.NbCompletedGames, 'second close does not double-count game');
  CheckEqualsInt(2, Game.NbCumulatedErrors, 'second close does not double-count errors');
  Check(not CheckAllSolved, 'closed game is not considered active and solved');

  Solve;
  Check(not CheckAllSolved, 'solve command does not alter inactive game state');

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

procedure TestInvalidDigitQueries;
begin
  InitGameWithSeed(6506);
  StartNewGameCore;

  Check(not DigitSolved(-1), 'negative digit is not solved');
  Check(not DigitSolved(DigitCount), 'out-of-range digit is not solved');
  Check(not DigitAppears(-1, 0, -1), 'negative digit does not appear');
  Check(not DigitAppears(DigitCount, 0, -1), 'out-of-range digit does not appear');
  CheckEqualsChar('?', CharForDigit(-1), 'negative digit renders as placeholder');
  CheckEqualsChar('?', CharForDigit(DigitCount),
    'out-of-range digit renders as placeholder');
end;

procedure TestInvalidMappingState;
var
  CorrectDigit: Integer;
  LetterChar: Char;
  DigitChar: Char;
begin
  InitGameWithSeed(6606);
  StartNewGameCore;

  Game.DigitToLetter[0] := DigitCount;
  CheckEqualsChar('?', CharForDigit(0), 'invalid digit-to-letter mapping renders safely');

  Game.LetterToDigit[0] := DigitCount;
  CheckEqualsGuess(grBadInput, TryProposal('A', '1', CorrectDigit),
    'proposal rejects invalid letter-to-digit mapping');
  CheckEqualsInt(-1, CorrectDigit, 'invalid proposal mapping leaves no correct digit');
  CheckEqualsGuess(grBadInput, TryGuess('A1', LetterChar, DigitChar, CorrectDigit),
    'guess rejects invalid letter-to-digit mapping');
  CheckEqualsInt(-1, CorrectDigit, 'invalid guess mapping leaves no correct digit');
end;

procedure TestRepeatedPartialSolutionsAfterRestart;
var
  Seed: LongInt;
  Solved: Boolean;
begin
  for Seed := 7001 to 7050 do
  begin
    InitGameWithSeed(Seed);
    StartNewGameCore;

    Solve(2, -1);
    Solved := CheckAllSolved;
    if not Solved then
    begin
      Solve(4, -1);
      Check(CheckAllSolved, 'first game solved by solution rows 1 and 2');
    end;
    CloseGameCore;

    StartNewGameCore;
    Solve(2, -1);
    Solved := CheckAllSolved;
    Check(Game.InProgress, 'second game remains usable after solution row 1');
    CheckEqualsInt(1, Game.NbCompletedGames,
      'checking second game does not mutate completed statistics');
  end;
end;

procedure TestPartialSolutionPairsDoNotHang;
var
  Seed: LongInt;
  FirstRow: Integer;
  SecondRow: Integer;
begin
  for Seed := 8001 to 8100 do
    for FirstRow := 1 to 5 do
      for SecondRow := 1 to 5 do
      begin
        InitGameWithSeed(Seed);
        StartNewGameCore;
        Solve(FirstRow * 2, -1);
        CheckAllSolved;
        Solve(SecondRow * 2, -1);
        CheckAllSolved;
        Check(Game.InProgress, 'partial solution pair leaves game lifecycle active');
      end;
end;

procedure CheckGuessSideEffects(const ResultCode: TGuessResult;
  const BeforeErrors, BeforeCompleted, BeforeCumulated: Integer;
  const Context: string);
begin
  CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
    Context + ': guess does not change completed count');
  CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
    Context + ': guess does not change cumulated errors');
  if ResultCode = grIncorrect then
    CheckEqualsInt(BeforeErrors + 1, Game.NbErrors,
      Context + ': incorrect guess increments errors once')
  else
    CheckEqualsInt(BeforeErrors, Game.NbErrors,
      Context + ': non-incorrect guess does not change errors');
end;

function FuzzGuessText(var State: Int64): string;
var
  LetterChar: Char;
  DigitChar: Char;
begin
  LetterChar := Chr(Ord('A') + NextFuzz(State, 10));
  DigitChar := Chr(Ord('0') + NextFuzz(State, 10));

  case NextFuzz(State, 8) of
    0: Result := LetterChar + DigitChar;
    1: Result := LetterChar + '=' + DigitChar;
    2: Result := LetterChar + ' ' + DigitChar;
    3: Result := LetterChar + ' = ' + DigitChar;
    4: Result := 'solution ' + IntToStr(1 + NextFuzz(State, 5));
    5: Result := 'quit1';
    6: Result := LetterChar + DigitChar + ' later';
  else
    Result := 'not-a-guess';
  end;
end;

procedure TestFuzzedStateTransitions;
var
  Seed: LongInt;
  Step: Integer;
  Action: Integer;
  State: Int64;
  Context: string;
  BeforeErrors: Integer;
  BeforeCompleted: Integer;
  BeforeCumulated: Integer;
  BeforeSolved: Integer;
  WasActive: Boolean;
  ResultCode: TGuessResult;
  LetterChar: Char;
  DigitChar: Char;
  CorrectDigit: Integer;
  Lines: TBoardLines;
begin
  for Seed := 9001 to 9200 do
  begin
    InitGameWithSeed(Seed);
    StartNewGameCore;
    State := Seed + 1000003;
    CheckGameInvariants(Format('fuzz seed=%d initial', [Seed]));

    for Step := 1 to 80 do
    begin
      Action := NextFuzz(State, 12);
      Context := Format('fuzz seed=%d step=%d action=%d', [Seed, Step, Action]);
      BeforeErrors := Game.NbErrors;
      BeforeCompleted := Game.NbCompletedGames;
      BeforeCumulated := Game.NbCumulatedErrors;
      BeforeSolved := SolvedDigitCount;
      WasActive := Game.InProgress;

      case Action of
        0:
          begin
            Game.AllowDoubleMultiplicator := NextFuzz(State, 2) = 0;
            StartNewGameCore;
            Check(Game.InProgress, Context + ': start makes game active');
            CheckEqualsInt(0, Game.NbErrors, Context + ': start resets errors');
            CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
              Context + ': start preserves completed count');
            CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
              Context + ': start preserves cumulated errors');
          end;
        1:
          begin
            Solve((1 + NextFuzz(State, 5)) * 2, -1);
            CheckEqualsInt(BeforeErrors, Game.NbErrors,
              Context + ': row solve does not change errors');
            CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
              Context + ': row solve does not change completed count');
            CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
              Context + ': row solve does not change cumulated errors');
            if not WasActive then
              CheckEqualsInt(BeforeSolved, SolvedDigitCount,
                Context + ': inactive row solve does not mark digits');
          end;
        2:
          begin
            Solve;
            CheckEqualsInt(BeforeErrors, Game.NbErrors,
              Context + ': full solve does not change errors');
            CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
              Context + ': full solve does not change completed count');
            CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
              Context + ': full solve does not change cumulated errors');
            if not WasActive then
              CheckEqualsInt(BeforeSolved, SolvedDigitCount,
                Context + ': inactive full solve does not mark digits');
          end;
        3:
          begin
            CheckAllSolved;
            CheckEqualsInt(BeforeErrors, Game.NbErrors,
              Context + ': check solved does not change errors');
            CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
              Context + ': check solved does not change completed count');
            CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
              Context + ': check solved does not change cumulated errors');
          end;
        4:
          begin
            ResultCode := TryGuess(FuzzGuessText(State), LetterChar, DigitChar,
              CorrectDigit);
            CheckGuessSideEffects(ResultCode, BeforeErrors, BeforeCompleted,
              BeforeCumulated, Context + ': try guess');
            if ResultCode in [grCorrect, grIncorrect, grAlreadySolved,
              grDoesNotAppear, grDigitAlreadyPlaced] then
              Check((CorrectDigit >= 0) and (CorrectDigit < DigitCount),
                Context + ': active guess reports valid correct digit')
            else
              CheckEqualsInt(-1, CorrectDigit,
                Context + ': inactive or bad guess reports no correct digit');
          end;
        5:
          begin
            LetterChar := Chr(Ord('A') + NextFuzz(State, 12));
            DigitChar := Chr(Ord('0') + NextFuzz(State, 12));
            ResultCode := TryProposal(LetterChar, DigitChar, CorrectDigit);
            CheckGuessSideEffects(ResultCode, BeforeErrors, BeforeCompleted,
              BeforeCumulated, Context + ': try proposal');
            if ResultCode in [grCorrect, grIncorrect, grAlreadySolved,
              grDoesNotAppear, grDigitAlreadyPlaced] then
              Check((CorrectDigit >= 0) and (CorrectDigit < DigitCount),
                Context + ': active proposal reports valid correct digit')
            else
              CheckEqualsInt(-1, CorrectDigit,
                Context + ': inactive or bad proposal reports no correct digit');
          end;
        6:
          begin
            CloseGameCore;
            Check(not Game.InProgress, Context + ': close leaves no active game');
            if WasActive then
            begin
              CheckEqualsInt(BeforeCompleted + 1, Game.NbCompletedGames,
                Context + ': close increments completed count');
              CheckEqualsInt(BeforeCumulated + BeforeErrors,
                Game.NbCumulatedErrors, Context + ': close adds current errors');
            end
            else
            begin
              CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
                Context + ': inactive close preserves completed count');
              CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
                Context + ': inactive close preserves cumulated errors');
            end;
          end;
        7:
          begin
            Game.SolveWhenTrivial := NextFuzz(State, 2) = 0;
            CheckEqualsInt(BeforeErrors, Game.NbErrors,
              Context + ': option toggle preserves errors');
            CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
              Context + ': option toggle preserves completed count');
            CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
              Context + ': option toggle preserves cumulated errors');
          end;
        8:
          begin
            Lines := BuildBoardLines;
            CheckEqualsInt(10, Length(Lines), Context + ': board has ten rows');
            Check(Lines[10] <> '', Context + ': board render produces final row');
            CheckEqualsInt(BeforeErrors, Game.NbErrors,
              Context + ': board render preserves errors');
            CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
              Context + ': board render preserves completed count');
            CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
              Context + ': board render preserves cumulated errors');
          end;
        9:
          begin
            CharForDigit(NextFuzz(State, DigitCount + 4) - 2);
            CheckEqualsInt(BeforeErrors, Game.NbErrors,
              Context + ': digit render preserves errors');
            CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
              Context + ': digit render preserves completed count');
            CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
              Context + ': digit render preserves cumulated errors');
          end;
        10:
          begin
            Game.AllowDoubleMultiplicator := NextFuzz(State, 2) = 0;
            CheckEqualsInt(BeforeErrors, Game.NbErrors,
              Context + ': multiplicator option preserves errors');
            CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
              Context + ': multiplicator option preserves completed count');
            CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
              Context + ': multiplicator option preserves cumulated errors');
          end;
      else
        begin
          DigitSolved(NextFuzz(State, DigitCount + 4) - 2);
          DigitAppears(NextFuzz(State, DigitCount + 4) - 2, 0, -1);
          CheckEqualsInt(BeforeErrors, Game.NbErrors,
            Context + ': query action preserves errors');
          CheckEqualsInt(BeforeCompleted, Game.NbCompletedGames,
            Context + ': query action preserves completed count');
          CheckEqualsInt(BeforeCumulated, Game.NbCumulatedErrors,
            Context + ': query action preserves cumulated errors');
        end;
      end;

      CheckGameInvariants(Context);
    end;
  end;
end;

begin
  TestPermutation;
  TestPuzzleArithmeticAndCoordinates;
  TestBoardRendering;
  TestGuessParsing;
  TestGuessFlow;
  TestSolvingAndStatistics;
  TestPartialSolve;
  TestInvalidDigitQueries;
  TestInvalidMappingState;
  TestRepeatedPartialSolutionsAfterRestart;
  TestPartialSolutionPairsDoNotHang;
  TestFuzzedStateTransitions;

  if Failures = 0 then
  begin
    WriteLn(Checks, ' checks passed.');
    Halt(0);
  end;

  WriteLn(Failures, ' failure(s) out of ', Checks, ' checks.');
  Halt(1);
end.
