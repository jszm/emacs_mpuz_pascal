program MpuzPascal;

{$mode objfpc}{$H+}

{
  Pascal recreation of GNU Emacs mpuz.el.
  Copyright (C) 2026

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
}

uses
  SysUtils,
  mpuz_core;

function YesNoPrompt(const Prompt: string; DefaultValue: Boolean): Boolean;
var
  Answer: string;
begin
  Write(Prompt);
  ReadLn(Answer);
  Answer := Trim(Answer);
  if Answer = '' then
    Exit(DefaultValue);

  case UpCaseAscii(Answer[1]) of
    'Y': Result := True;
    'N': Result := False;
  else
    Result := DefaultValue;
  end;
end;

procedure PaintBoard;
var
  Lines: TBoardLines;
  I: Integer;
begin
  Lines := BuildBoardLines;
  for I := Low(Lines) to High(Lines) do
    WriteLn(Lines[I]);
end;

procedure StartNewGame;
begin
  WriteLn('Here we go...');
  StartNewGameCore;
  PaintBoard;
  WriteLn('Your try?');
end;

procedure CloseGame;
var
  MessageText: string;
  ErrorSuffix: string;
begin
  if Game.NbErrors = 1 then
    ErrorSuffix := ''
  else
    ErrorSuffix := 's';

  MessageText := Format('Puzzle solved with %d error%s. That''s %s',
    [Game.NbErrors, ErrorSuffix, ScoreText]);

  CloseGameCore;
  PaintBoard;
  WriteLn(MessageText);

  if YesNoPrompt(MessageText + ' Start a new game? ', False) then
    StartNewGame
  else
    WriteLn('Good Bye!');
end;

procedure TryGuessCommand(const Input: string);
var
  LetterChar: Char;
  DigitChar: Char;
  CorrectDigit: Integer;
  ResultCode: TGuessResult;
begin
  ResultCode := TryGuess(Input, LetterChar, DigitChar, CorrectDigit);

  case ResultCode of
    grNoGame:
      begin
        if YesNoPrompt('Start a new game? ', True) then
          StartNewGame
        else
          WriteLn('OK. I won''t.');
      end;
    grBadInput:
      WriteLn('Enter a letter A-J followed by a digit, for example A3 or A=3.');
    grAlreadySolved:
      WriteLn(LetterChar, ' already solved.');
    grDoesNotAppear:
      WriteLn(LetterChar, ' does not appear.');
    grDigitAlreadyPlaced:
      WriteLn(DigitChar, ' has already been placed.');
    grCorrect:
      begin
        WriteLn(LetterChar, ' = ', DigitChar, ' correct!');
        if CheckAllSolved then
          CloseGame
        else
          PaintBoard;
      end;
    grIncorrect:
      begin
        WriteLn(LetterChar, ' = ', DigitChar, ' incorrect!');
        PaintBoard;
      end;
  end;
end;

procedure ShowSolutionCommand(const Input: string);
var
  Arg: string;
  RowNumber: Integer;
  Code: Integer;
begin
  Arg := Trim(Copy(Input, Pos(' ', Input + ' ') + 1, MaxInt));

  if Arg = '' then
    Solve
  else
  begin
    Val(Arg, RowNumber, Code);
    if (Code <> 0) or (RowNumber < 1) or (RowNumber > 5) then
    begin
      WriteLn('Use solution or solution N, where N is 1..5.');
      Exit;
    end;
    Solve(RowNumber * 2, -1);
  end;

  if CheckAllSolved then
    CloseGame
  else
    PaintBoard;
end;

function IsCommand(const Input, Name: string): Boolean;
begin
  Result := (Input = Name) or (Pos(Name + ' ', Input) = 1);
end;

procedure PrintHelp;
begin
  WriteLn('Multiplication puzzle.');
  WriteLn('Each letter A-J stands for one digit 0-9.');
  WriteLn('Guess with A3, A=3, or A 3.');
  WriteLn('Commands: help, solution [1-5], new, abort, quit.');
end;

procedure AbortGame;
begin
  if YesNoPrompt('Abort game? ', False) then
  begin
    Game.InProgress := False;
    Game.NbErrors := 0;
    ClearBoard;
    WriteLn('Mult Puzzle aborted.');
  end
  else
    WriteLn('Your try?');
end;

procedure RunInteractive;
var
  LineInput: string;
  Command: string;
begin
  StartNewGame;

  repeat
    Write('> ');
    if EOF then
      Break;
    ReadLn(LineInput);
    Command := LowerCase(Trim(LineInput));

    if Command = '' then
      Continue
    else if (Command = '?') or (Command = 'help') then
      PrintHelp
    else if (Command = 'q') or (Command = 'quit') or (Command = 'exit') then
      Break
    else if Command = 'new' then
      StartNewGame
    else if Command = 'abort' then
      AbortGame
    else if IsCommand(Command, 'solution') then
      ShowSolutionCommand(Command)
    else if IsCommand(Command, 'solve') then
      ShowSolutionCommand('solution' + Copy(Command, 6, MaxInt))
    else
      TryGuessCommand(LineInput);
  until False;
end;

procedure RunSmoke;
begin
  StartNewGame;
  Solve;
  if not CheckAllSolved then
    Halt(2);
  WriteLn('Smoke check passed.');
end;

begin
  InitGame;

  if (ParamCount > 0) and ((ParamStr(1) = '--help') or (ParamStr(1) = '-h')) then
    PrintHelp
  else if (ParamCount > 0) and (ParamStr(1) = '--smoke') then
    RunSmoke
  else
    RunInteractive;
end.
