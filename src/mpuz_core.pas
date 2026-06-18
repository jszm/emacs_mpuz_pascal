unit mpuz_core;

{$mode objfpc}{$H+}

{
  Pascal recreation of GNU Emacs mpuz.el.
  Copyright (C) 2026

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
}

interface

uses
  SysUtils;

const
  DigitCount = 10;
  MaxSquaresPerDigit = 32;
  StatsLabelColumn = 30;
  StatsValueColumn = 60;

type
  TSquare = record
    Row: Integer;
    Col: Integer;
  end;

  TSquareList = record
    Count: Integer;
    Items: array[0..MaxSquaresPerDigit - 1] of TSquare;
  end;

  TBoardLines = array[1..10] of string;

  TMpuzGame = record
    DigitToLetter: array[0..DigitCount - 1] of Integer;
    LetterToDigit: array[0..DigitCount - 1] of Integer;
    FoundDigits: array[0..DigitCount - 1] of Boolean;
    TrivialDigits: array[0..DigitCount - 1] of Boolean;
    Board: array[0..DigitCount - 1] of TSquareList;
    NbErrors: Integer;
    NbCompletedGames: Integer;
    NbCumulatedErrors: Integer;
    InProgress: Boolean;
    SolveWhenTrivial: Boolean;
    AllowDoubleMultiplicator: Boolean;
  end;

  TGuessResult = (
    grNoGame,
    grBadInput,
    grAlreadySolved,
    grDoesNotAppear,
    grDigitAlreadyPlaced,
    grCorrect,
    grIncorrect
  );

  TRandomIntProvider = function(const Limit: Integer): Integer;

var
  Game: TMpuzGame;

function UpCaseAscii(const Ch: Char): Char;
function AverageErrorsText: string;
function DigitSolved(const Digit: Integer): Boolean;
function DigitAppears(const Digit, Row, Col: Integer): Boolean;
function CharForDigit(const Digit: Integer): Char;
function BuildBoardLines: TBoardLines;
function CheckAllSolved(const Row: Integer = 0; const Col: Integer = -1): Boolean;
function ScoreText: string;
function ExtractGuess(const Input: string; out LetterChar, DigitChar: Char): Boolean;
function TryProposal(const LetterChar, DigitChar: Char; out CorrectDigit: Integer): TGuessResult;
function TryGuess(const Input: string; out LetterChar, DigitChar: Char;
  out CorrectDigit: Integer): TGuessResult;

procedure InitGame;
procedure InitGameWithSeed(const Seed: LongInt);
procedure SetRandomIntProvider(const Provider: TRandomIntProvider);
procedure ResetRandomIntProvider;
procedure ClearBoard;
procedure ClearDigitState;
procedure BuildRandomPerm;
procedure RandomPuzzle;
procedure Solve(const Row: Integer = 0; const Col: Integer = -1);
procedure StartNewGameCore;
procedure CloseGameCore;

implementation

var
  RandomIntProvider: TRandomIntProvider = nil;

function UpCaseAscii(const Ch: Char): Char;
begin
  if (Ch >= 'a') and (Ch <= 'z') then
    Result := Chr(Ord(Ch) - Ord('a') + Ord('A'))
  else
    Result := Ch;
end;

function IsAsciiWhitespace(const Ch: Char): Boolean;
begin
  Result := Ord(Ch) <= Ord(' ');
end;

function ValidDigit(const Digit: Integer): Boolean;
begin
  Result := (Digit >= 0) and (Digit < DigitCount);
end;

function NextRandomInt(const Limit: Integer): Integer;
begin
  if Limit <= 0 then
    raise Exception.CreateFmt('invalid random limit %d', [Limit]);

  if Assigned(RandomIntProvider) then
    Result := RandomIntProvider(Limit)
  else
    Result := Random(Limit);

  if (Result < 0) or (Result >= Limit) then
    raise Exception.CreateFmt('random provider returned %d for limit %d',
      [Result, Limit]);
end;

function AverageErrorsText: string;
var
  Value: Double;
begin
  if Game.NbCompletedGames = 0 then
    Value := 0.0
  else
    Value := Game.NbCumulatedErrors / Game.NbCompletedGames;

  Result := Format('%.2f', [Value]);
  if DefaultFormatSettings.DecimalSeparator <> '.' then
    Result := StringReplace(Result, DefaultFormatSettings.DecimalSeparator, '.',
      [rfReplaceAll]);
end;

function DigitSolved(const Digit: Integer): Boolean;
begin
  if not ValidDigit(Digit) then
    Exit(False);

  Result := Game.FoundDigits[Digit] or Game.TrivialDigits[Digit];
end;

procedure ClearBoard;
var
  Digit: Integer;
begin
  for Digit := 0 to DigitCount - 1 do
    Game.Board[Digit].Count := 0;
end;

procedure ClearDigitState;
var
  Digit: Integer;
begin
  for Digit := 0 to DigitCount - 1 do
  begin
    Game.FoundDigits[Digit] := False;
    Game.TrivialDigits[Digit] := False;
  end;
end;

procedure AddSquare(const Digit, Row, Col: Integer);
var
  Count: Integer;
begin
  Count := Game.Board[Digit].Count;
  if Count >= MaxSquaresPerDigit then
    raise Exception.Create('internal board square limit exceeded');

  Game.Board[Digit].Items[Count].Row := Row;
  Game.Board[Digit].Items[Count].Col := Col;
  Inc(Game.Board[Digit].Count);
end;

procedure PutNumberOnBoard(Number, Row: Integer; const Columns: array of Integer);
var
  I: Integer;
  Digit: Integer;
begin
  for I := Low(Columns) to High(Columns) do
  begin
    Digit := Number mod 10;
    Number := Number div 10;
    AddSquare(Digit, Row, Columns[I]);
  end;
end;

procedure BuildRandomPerm;
var
  Letters: array[0..DigitCount - 1] of Integer;
  Count: Integer;
  Index: Integer;
  Pos: Integer;
  Elem: Integer;
  I: Integer;
begin
  for I := 0 to DigitCount - 1 do
    Letters[I] := I;

  Count := DigitCount;
  Index := DigitCount;
  while Count > 0 do
  begin
    Pos := NextRandomInt(Count);
    Elem := Letters[Pos];

    for I := Pos to Count - 2 do
      Letters[I] := Letters[I + 1];

    Dec(Count);
    Dec(Index);
    Game.DigitToLetter[Index] := Elem;
    Game.LetterToDigit[Elem] := Index;
  end;
end;

procedure RandomPuzzle;
var
  A: Integer;
  MinDigit: Integer;
  B1: Integer;
  B2: Integer;
  C: Integer;
  D: Integer;
  E: Integer;
begin
  BuildRandomPerm;
  ClearBoard;

  if Game.AllowDoubleMultiplicator then
    A := 112 + NextRandomInt(888)
  else
    A := 125 + NextRandomInt(875);

  MinDigit := 1 + (999 div A);
  B1 := MinDigit + NextRandomInt(10 - MinDigit);
  repeat
    B2 := MinDigit + NextRandomInt(10 - MinDigit);
  until Game.AllowDoubleMultiplicator or (B1 <> B2);

  C := A * B2;
  D := A * B1;
  E := C + (D * 10);

  PutNumberOnBoard(A, 2, [9, 7, 5]);
  PutNumberOnBoard((B1 * 10) + B2, 4, [9, 7]);
  PutNumberOnBoard(C, 6, [9, 7, 5, 3]);
  PutNumberOnBoard(D, 8, [7, 5, 3, 1]);
  PutNumberOnBoard(E, 10, [9, 7, 5, 3, 1]);
end;

function DigitAppears(const Digit, Row, Col: Integer): Boolean;
var
  I: Integer;
  Square: TSquare;
begin
  Result := False;
  if not ValidDigit(Digit) then
    Exit;

  if Game.Board[Digit].Count = 0 then
    Exit;

  if Row = 0 then
    Exit(True);

  for I := 0 to Game.Board[Digit].Count - 1 do
  begin
    Square := Game.Board[Digit].Items[I];
    if (Square.Row = Row) and ((Col < 0) or (Square.Col = Col)) then
      Exit(True);
  end;
end;

function MarkSolved(const Row: Integer = 0; const Col: Integer = -1): Boolean;
var
  Digit: Integer;
begin
  Result := False;
  if not Game.InProgress then
    Exit;

  for Digit := 0 to DigitCount - 1 do
    if (not DigitSolved(Digit)) and ((Row = 0) or DigitAppears(Digit, Row, Col)) then
    begin
      Game.TrivialDigits[Digit] := True;
      Result := True;
    end;
end;

procedure Solve(const Row: Integer = 0; const Col: Integer = -1);
begin
  MarkSolved(Row, Col);
end;

function CheckAllSolved(const Row: Integer = 0; const Col: Integer = -1): Boolean;
var
  Digit: Integer;
  A: Boolean;
  B1: Boolean;
  B2: Boolean;
  C: Boolean;
  D: Boolean;
  E: Boolean;
  Changed: Boolean;
begin
  if not Game.InProgress then
    Exit(False);

  if Game.SolveWhenTrivial and (Row = 0) then
  begin
    A := False;
    B1 := False;
    B2 := False;
    C := False;
    D := False;
    E := False;

    repeat
      Changed := False;

      if not B1 then
        B1 := CheckAllSolved(4, 7);
      if not B2 then
        B2 := CheckAllSolved(4, 9);
      if not E then
        E := CheckAllSolved(10, -1);
      if not A then
        A := CheckAllSolved(2, -1);

      if (A and B1 and B2) or (E and (A or (B1 and B2))) then
      begin
        Solve;
        Exit(True);
      end;

      if not D then
        D := CheckAllSolved(8, -1);
      if not C then
        C := CheckAllSolved(6, -1);

      if C and D and (not E) then
      begin
        Changed := MarkSolved(10, -1);
      end
      else if E and (C <> D) then
      begin
        if D then
          Changed := MarkSolved(6, -1)
        else
          Changed := MarkSolved(8, -1);
      end
      else if A and (B2 <> C) then
      begin
        if C then
          Changed := MarkSolved(4, 9)
        else
          Changed := MarkSolved(6, 9);
      end
      else if A and (B1 <> D) then
      begin
        if D then
          Changed := MarkSolved(4, 7)
        else
          Changed := MarkSolved(8, 7);
      end
      else if (not A) and ((B2 and C) or (B1 and D)) then
      begin
        Changed := MarkSolved(2, -1);
      end;
    until not Changed;
  end;

  for Digit := 0 to DigitCount - 1 do
    if (not DigitSolved(Digit)) and DigitAppears(Digit, Row, Col) then
      Exit(False);

  Result := True;
end;

procedure SetCharAtColumn(var Line: string; const Col: Integer; const Ch: Char);
var
  Pos: Integer;
begin
  Pos := Col + 1;
  if Length(Line) < Pos then
    Line := Line + StringOfChar(' ', Pos - Length(Line));
  Line[Pos] := Ch;
end;

function CharForDigit(const Digit: Integer): Char;
var
  Letter: Integer;
begin
  if not ValidDigit(Digit) then
    Exit('?');

  if DigitSolved(Digit) then
    Result := Chr(Ord('0') + Digit)
  else
  begin
    Letter := Game.DigitToLetter[Digit];
    if not ValidDigit(Letter) then
      Exit('?');
    Result := Chr(Ord('A') + Letter);
  end;
end;

procedure PaintDigit(var Lines: TBoardLines; const Digit: Integer);
var
  I: Integer;
  Square: TSquare;
begin
  for I := 0 to Game.Board[Digit].Count - 1 do
  begin
    Square := Game.Board[Digit].Items[I];
    if (Square.Row >= Low(Lines)) and (Square.Row <= High(Lines)) then
      SetCharAtColumn(Lines[Square.Row], Square.Col, CharForDigit(Digit));
  end;
end;

function PadToColumn(const Prefix: string; const Column: Integer): string;
begin
  Result := Prefix;
  if Length(Result) < Column then
    Result := Result + StringOfChar(' ', Column - Length(Result));
end;

function StatsLine(const Prefix, LabelText, ValueText: string): string;
begin
  Result := PadToColumn(Prefix, StatsLabelColumn) + LabelText;
  Result := PadToColumn(Result, StatsValueColumn) + ValueText;
end;

function BuildBoardLines: TBoardLines;
var
  Digit: Integer;
begin
  Result[1] := '';
  Result[2] := '     . . .';
  Result[3] := StatsLine('', 'Number of errors (this game):',
    IntToStr(Game.NbErrors));
  Result[4] := '    x  . .';
  Result[5] := '   -------';
  Result[6] := '   . . . .';
  Result[7] := StatsLine('', 'Number of completed games:',
    IntToStr(Game.NbCompletedGames));
  Result[8] := ' . . . .';
  Result[9] := StatsLine(' ---------', 'Average number of errors:',
    AverageErrorsText);
  Result[10] := ' . . . . .';

  for Digit := 0 to DigitCount - 1 do
    PaintDigit(Result, Digit);
end;

procedure StartNewGameCore;
begin
  Game.NbErrors := 0;
  Game.InProgress := True;
  ClearDigitState;
  RandomPuzzle;
end;

function ScoreText: string;
begin
  case Game.NbErrors of
    0: Result := 'perfect!';
    1: Result := 'very good!';
    2: Result := 'good.';
    3: Result := 'not bad.';
    4: Result := 'not too bad...';
  else
    if Game.NbErrors < 10 then
      Result := 'bad!'
    else if Game.NbErrors < 15 then
      Result := 'awful.'
    else
      Result := 'not serious.';
  end;
end;

procedure CloseGameCore;
begin
  if not Game.InProgress then
    Exit;

  Game.InProgress := False;
  Inc(Game.NbCumulatedErrors, Game.NbErrors);
  Inc(Game.NbCompletedGames);
end;

function ExtractGuess(const Input: string; out LetterChar, DigitChar: Char): Boolean;
var
  I: Integer;
  Text: string;
  ParsedLetter: Char;
  ParsedDigit: Char;
begin
  Result := False;
  LetterChar := #0;
  DigitChar := #0;
  Text := Trim(Input);
  if Text = '' then
    Exit;

  I := 1;
  ParsedLetter := UpCaseAscii(Text[I]);
  if (ParsedLetter < 'A') or (ParsedLetter > 'J') then
    Exit;

  Inc(I);
  while (I <= Length(Text)) and IsAsciiWhitespace(Text[I]) do
    Inc(I);

  if (I <= Length(Text)) and (Text[I] = '=') then
  begin
    Inc(I);
    while (I <= Length(Text)) and IsAsciiWhitespace(Text[I]) do
      Inc(I);
  end;

  if (I > Length(Text)) or (Text[I] < '0') or (Text[I] > '9') then
    Exit;

  ParsedDigit := Text[I];
  Inc(I);
  while (I <= Length(Text)) and IsAsciiWhitespace(Text[I]) do
    Inc(I);

  if I <= Length(Text) then
    Exit;

  LetterChar := ParsedLetter;
  DigitChar := ParsedDigit;
  Result := True;
end;

function TryProposal(const LetterChar, DigitChar: Char; out CorrectDigit: Integer): TGuessResult;
var
  Letter: Integer;
  Digit: Integer;
begin
  CorrectDigit := -1;
  if not Game.InProgress then
    Exit(grNoGame);

  Letter := Ord(UpCaseAscii(LetterChar)) - Ord('A');
  Digit := Ord(DigitChar) - Ord('0');

  if (Letter < 0) or (Letter >= DigitCount) or (Digit < 0) or (Digit >= DigitCount) then
    Exit(grBadInput);

  CorrectDigit := Game.LetterToDigit[Letter];
  if not ValidDigit(CorrectDigit) then
  begin
    CorrectDigit := -1;
    Exit(grBadInput);
  end;

  if DigitSolved(CorrectDigit) then
    Result := grAlreadySolved
  else if Game.Board[CorrectDigit].Count = 0 then
    Result := grDoesNotAppear
  else if DigitSolved(Digit) then
    Result := grDigitAlreadyPlaced
  else if Digit = CorrectDigit then
  begin
    Game.FoundDigits[Digit] := True;
    Result := grCorrect;
  end
  else
  begin
    Inc(Game.NbErrors);
    Result := grIncorrect;
  end;
end;

function TryGuess(const Input: string; out LetterChar, DigitChar: Char;
  out CorrectDigit: Integer): TGuessResult;
begin
  LetterChar := #0;
  DigitChar := #0;
  CorrectDigit := -1;

  if not Game.InProgress then
    Exit(grNoGame);

  if not ExtractGuess(Input, LetterChar, DigitChar) then
    Exit(grBadInput);

  Result := TryProposal(LetterChar, DigitChar, CorrectDigit);
end;

procedure ResetGameDefaults;
begin
  FillChar(Game, SizeOf(Game), 0);
  Game.SolveWhenTrivial := True;
  Game.AllowDoubleMultiplicator := False;
end;

procedure InitGame;
begin
  Randomize;
  ResetGameDefaults;
end;

procedure InitGameWithSeed(const Seed: LongInt);
begin
  ResetGameDefaults;
  RandSeed := Seed;
end;

procedure SetRandomIntProvider(const Provider: TRandomIntProvider);
begin
  RandomIntProvider := Provider;
end;

procedure ResetRandomIntProvider;
begin
  RandomIntProvider := nil;
end;

end.
