{**********************************************************************}
{                                                                      }
{    "The contents of this file are subject to the Mozilla Public      }
{    License Version 1.1 (the "License"); you may not use this         }
{    file except in compliance with the License. You may obtain        }
{    a copy of the License at http://www.mozilla.org/MPL/              }
{                                                                      }
{    Software distributed under the License is distributed on an       }
{    "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express       }
{    or implied. See the License for the specific language             }
{    governing rights and limitations under the License.               }
{                                                                      }
{    The Initial Developer of the Original Code is Matthias            }
{    Ackermann. For other initial contributors, see contributors.txt   }
{    Subsequent portions Copyright Creative IT.                        }
{                                                                      }
{    Current maintainer: Eric Grange                                   }
{                                                                      }
{**********************************************************************}
unit dwsExprList;

{$I dws.inc}

interface

uses
   dwsUtils, dwsXPlatform, dwsDateTime, dwsErrors,
   dwsSymbols;

type

   // TExprBaseListExec
   //
   PExprBaseListRec = ^TExprBaseListRec;
   TExprBaseListRec = record
      private
         FList : TTightList;

         function GetExprBase(const x : Integer) : TExprBase; inline;
         procedure SetExprBase(const x : Integer; expr : TExprBase);

      public
         procedure Clean;
         procedure Clear;

         function Add(expr : TExprBase) : Integer; inline;
         procedure Insert(idx : Integer;expr : TExprBase); inline;
         procedure Delete(index : Integer);
         procedure Assign(const src : TExprBaseListRec);

         property ExprBase[const x : Integer] : TExprBase read GetExprBase write SetExprBase; default;
         property Count : Integer read FList.FCount;
   end;

   // TExprBaseListExec
   //
   TExprBaseListExec = record
      private
         FList : PObjectTightList;
         FCount : Integer;
         FExec : TdwsExecution;
         FExpr : TObject;

         procedure SetListRec(const lr : TExprBaseListRec); inline;

         function GetExprBase(const x : Integer): TExprBase; {$IFNDEF VER200}inline;{$ENDIF} // D2009 Compiler bug workaround
         procedure SetExprBase(const x : Integer; expr : TExprBase); inline;

         function GetAsInteger(const x : Integer) : Int64; inline;
         procedure SetAsInteger(const x : Integer; const value : Int64);
         function GetAsBoolean(const x : Integer) : Boolean; inline;
         procedure SetAsBoolean(const x : Integer; const value : Boolean);
         function GetAsFloat(const x : Integer) : Double; inline;
         procedure SetAsFloat(const x : Integer; const value : Double);
         function GetAsString(const x : Integer) : UnicodeString; inline;
         procedure SetAsString(const x : Integer; const value : UnicodeString);
         function GetAsDataString(const x : Integer) : RawByteString; inline;
         procedure SetAsDataString(const x : Integer; const value : RawByteString);
         function GetAsFileName(const x : Integer) : UnicodeString;
         function GetFormatSettings : TdwsFormatSettings; inline;

      public
         property ListRec : TExprBaseListRec write SetListRec;
         property List : PObjectTightList read FList;
         property Count : Integer read FCount;
         property Exec : TdwsExecution read FExec write FExec;
         property FormatSettings : TdwsFormatSettings read GetFormatSettings;
         property Expr : TObject read FExpr write FExpr;

         property ExprBase[const x : Integer] : TExprBase read GetExprBase write SetExprBase; default;

         procedure EvalAsVariant(const x : Integer; var result : Variant); inline;
         procedure EvalAsString(const x : Integer; var result : UnicodeString); inline;

         function AsChar(x : Integer; default : WideChar) : WideChar;

         property AsInteger[const x : Integer] : Int64 read GetAsInteger write SetAsInteger;
         property AsBoolean[const x : Integer] : Boolean read GetAsBoolean write SetAsBoolean;
         property AsFloat[const x : Integer] : Double read GetAsFloat write SetAsFloat;
         property AsString[const x : Integer] : UnicodeString read GetAsString write SetAsString;
         property AsDataString[const x : Integer] : RawByteString read GetAsDataString write SetAsDataString;

         property AsFileName[const x : Integer] : UnicodeString read GetAsFileName;
   end;

   TSimpleCallbackExprBase = function (var item : TExprBase) : TSimpleCallbackStatus;

   // TSortedExprBaseList
   //
   TSortedExprBaseList = class
      private
         type
            TArrayOFExprBase = array of TExprBase;
         var
            FItems : TArrayOFExprBase;
            FCount : Integer;

      protected
         function GetItem(index : Integer) : TExprBase;
         function Find(const item : TExprBase; var index : Integer) : Boolean;
         function Compare(const item1, item2 : TExprBase) : Integer; virtual; abstract;
         procedure InsertItem(index : Integer; const anItem : TExprBase);

      public
         function Add(const anItem : TExprBase) : Integer;
         function AddOrFind(const anItem : TExprBase; var added : Boolean) : Integer;
         function Extract(const anItem : TExprBase) : Integer;
         function ExtractAt(index : Integer) : TExprBase;
         function IndexOf(const anItem : TExprBase) : Integer;
         procedure Clear;
         procedure Clean;
         procedure Enumerate(const callback : TSimpleCallbackExprBase);
         property Items[index : Integer] : TExprBase read GetItem; default;
         property Count : Integer read FCount;
   end;


// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

// ------------------
// ------------------ TExprBaseListRec ------------------
// ------------------

// Clean
//
procedure TExprBaseListRec.Clean;
begin
   FList.Clean;
end;

// Clear
//
procedure TExprBaseListRec.Clear;
begin
   FList.Clear;
end;

// Add
//
function TExprBaseListRec.Add(expr : TExprBase) : Integer;
begin
   Result:=FList.Add(expr);
end;

// Insert
//
procedure TExprBaseListRec.Insert(idx : Integer;expr : TExprBase);
begin
   FList.Insert(0, expr);
end;

// Delete
//
procedure TExprBaseListRec.Delete(index : Integer);
begin
   FList.Delete(index);
end;

// Assign
//
procedure TExprBaseListRec.Assign(const src : TExprBaseListRec);
begin
   FList.Assign(src.FList);
end;

// GetExprBase
//
function TExprBaseListRec.GetExprBase(const x : Integer): TExprBase;
begin
   Result:=TExprBase(FList.List[x]);
end;

// SetExprBase
//
procedure TExprBaseListRec.SetExprBase(const x : Integer; expr : TExprBase);
begin
   FList.List[x]:=expr;
end;

// ------------------
// ------------------ TExprBaseListExec ------------------
// ------------------

// SetListRec
//
procedure TExprBaseListExec.SetListRec(const lr : TExprBaseListRec);
begin
   FCount:=lr.FList.Count;
   FList:=lr.FList.List;
end;

// GetExprBase
//
function TExprBaseListExec.GetExprBase(const x: Integer): TExprBase;
begin
   Result:=TExprBase(FList[x]);
end;

// SetExprBase
//
procedure TExprBaseListExec.SetExprBase(const x : Integer; expr : TExprBase);
begin
   FList[x]:=expr;
end;

// GetAsInteger
//
function TExprBaseListExec.GetAsInteger(const x : Integer) : Int64;
begin
   Result:=ExprBase[x].EvalAsInteger(Exec);
end;

// SetAsInteger
//
procedure TExprBaseListExec.SetAsInteger(const x : Integer; const value : Int64);
begin
   ExprBase[x].AssignValueAsInteger(Exec, value);
end;

// GetAsBoolean
//
function TExprBaseListExec.GetAsBoolean(const x : Integer) : Boolean;
begin
   Result:=ExprBase[x].EvalAsBoolean(Exec);
end;

// SetAsBoolean
//
procedure TExprBaseListExec.SetAsBoolean(const x : Integer; const value : Boolean);
begin
   ExprBase[x].AssignValueAsBoolean(Exec, value);
end;

// GetAsFloat
//
function TExprBaseListExec.GetAsFloat(const x : Integer) : Double;
begin
   Result:=ExprBase[x].EvalAsFloat(Exec);
end;

// SetAsFloat
//
procedure TExprBaseListExec.SetAsFloat(const x : Integer; const value : Double);
begin
   ExprBase[x].AssignValueAsFloat(Exec, value);
end;

// GetAsString
//
function TExprBaseListExec.GetAsString(const x : Integer) : UnicodeString;
begin
   ExprBase[x].EvalAsString(Exec, Result);
end;

// SetAsString
//
procedure TExprBaseListExec.SetAsString(const x : Integer; const value : UnicodeString);
begin
   ExprBase[x].AssignValueAsString(Exec, value);
end;

// GetAsDataString
//
function TExprBaseListExec.GetAsDataString(const x : Integer) : RawByteString;
begin
   ScriptStringToRawByteString(GetAsString(x), Result);
end;

// SetAsDataString
//
procedure TExprBaseListExec.SetAsDataString(const x : Integer; const value : RawByteString);
begin
   ExprBase[x].AssignValueAsString(Exec, RawByteStringToScriptString(value));
end;

// GetAsFileName
//
function TExprBaseListExec.GetAsFileName(const x : Integer) : UnicodeString;
begin
   Result:=Exec.ValidateFileName(AsString[x]);
end;

// GetFormatSettings
//
function TExprBaseListExec.GetFormatSettings : TdwsFormatSettings;
begin
   Result:=Exec.FormatSettings;
end;

// EvalAsVariant
//
procedure TExprBaseListExec.EvalAsVariant(const x : Integer; var result : Variant);
begin
   ExprBase[x].EvalAsVariant(Exec, result);
end;

// EvalAsString
//
procedure TExprBaseListExec.EvalAsString(const x : Integer; var result : UnicodeString);
begin
   ExprBase[x].EvalAsString(Exec, result);
end;

// AsChar
//
function TExprBaseListExec.AsChar(x : Integer; default : WideChar) : WideChar;
var
   s : UnicodeString;
begin
   EvalAsString(x, s);
   if s <> '' then
      Result := PWideChar(Pointer(s))^
   else Result := default;
end;

// ------------------
// ------------------ TSortedExprBaseList ------------------
// ------------------

// GetItem
//
function TSortedExprBaseList.GetItem(index : Integer) : TExprBase;
begin
   Result:=FItems[index];
end;

// Find
//
function TSortedExprBaseList.Find(const item : TExprBase; var index : Integer) : Boolean;
var
   lo, hi, mid, compResult : Integer;
begin
   Result:=False;
   lo:=0;
   hi:=FCount-1;
   while lo<=hi do begin
      mid:=(lo+hi) shr 1;
      compResult:=Compare(FItems[mid], item);
      if compResult<0 then
         lo:=mid+1
      else begin
         hi:=mid- 1;
         if compResult=0 then
            Result:=True;
      end;
   end;
   index:=lo;
end;

// InsertItem
//
procedure TSortedExprBaseList.InsertItem(index : Integer; const anItem : TExprBase);
begin
   if Count=Length(FItems) then
      SetLength(FItems, Count+8+(Count shr 4));
   if index<Count then
      System.Move(FItems[index], FItems[index+1], (Count-index)*SizeOf(Pointer));
   Inc(FCount);
   FItems[index]:=anItem;
end;

// Add
//
function TSortedExprBaseList.Add(const anItem : TExprBase) : Integer;
begin
   Find(anItem, Result);
   InsertItem(Result, anItem);
end;

// AddOrFind
//
function TSortedExprBaseList.AddOrFind(const anItem : TExprBase; var added : Boolean) : Integer;
begin
   added:=not Find(anItem, Result);
   if added then
      InsertItem(Result, anItem);
end;

// Extract
//
function TSortedExprBaseList.Extract(const anItem : TExprBase) : Integer;
begin
   if Find(anItem, Result) then
      ExtractAt(Result)
   else Result:=-1;
end;

// ExtractAt
//
function TSortedExprBaseList.ExtractAt(index : Integer) : TExprBase;
var
   n : Integer;
begin
   Dec(FCount);
   Result:=FItems[index];
   n:=FCount-index;
   if n>0 then
      System.Move(FItems[index+1], FItems[index], n*SizeOf(TExprBase));
   SetLength(FItems, FCount);
end;

// IndexOf
//
function TSortedExprBaseList.IndexOf(const anItem : TExprBase) : Integer;
begin
   if not Find(anItem, Result) then
      Result:=-1;
end;

// Clear
//
procedure TSortedExprBaseList.Clear;
begin
   SetLength(FItems, 0);
   FCount:=0;
end;

// Clean
//
procedure TSortedExprBaseList.Clean;
var
   i : Integer;
begin
   for i:=0 to FCount-1 do
      FItems[i].Free;
   Clear;
end;

// Enumerate
//
procedure TSortedExprBaseList.Enumerate(const callback : TSimpleCallbackExprBase);
var
   i : Integer;
begin
   for i:=0 to Count-1 do
      if callback(FItems[i])=csAbort then
         Break;
end;

end.
