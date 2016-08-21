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
unit dwsExternalSymbols;

{$I dws.inc}

interface

uses
   dwsUtils,
   dwsExprs, dwsSymbols;

type

   IExternalSymbolHandler = interface
      ['{9217DE55-C4A6-40F4-99FC-3186967B96B5}']
      procedure Assign(exec : TdwsExecution; symbol : TDataSymbol; expr : TTypedExpr; var handled : Boolean);
      procedure Eval(exec : TdwsExecution; symbol : TDataSymbol; var handled : Boolean; var result : Variant);
   end;

   TExternalSymbolHandler = class (TInterfacedSelfObject, IExternalSymbolHandler)
      public
         procedure Assign(exec : TdwsExecution; symbol : TDataSymbol; expr : TTypedExpr; var handled : Boolean); virtual;
         procedure Eval(exec : TdwsExecution; symbol : TDataSymbol; var handled : Boolean; var result : Variant); virtual;

         class procedure Register(symbol : TSymbol; const handler : IExternalSymbolHandler); static;

         class procedure HandleAssign(exec : TdwsExecution; symbol : TDataSymbol; expr : TTypedExpr; var handled : Boolean); static;
         class procedure HandleEval(exec : TdwsExecution; symbol : TDataSymbol; var handled : Boolean; var result : Variant); static;
   end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

type
   TSimpleCallbackIExternalSymbolHandler = function (var item : IExternalSymbolHandler) : TSimpleCallbackStatus;

   // TSimpleListIExternalSymbolHandler
   //
   TSimpleListIExternalSymbolHandler = class
      private
         type
            ArrayT = array of IExternalSymbolHandler;
         var
            FItems : ArrayT;
            FCount : Integer;
            FCapacity : Integer;

      protected
         procedure Grow;
         function GetItems(const idx : Integer) : IExternalSymbolHandler; {$IFDEF DELPHI_2010_MINUS}{$ELSE} inline; {$ENDIF}
         procedure SetItems(const idx : Integer; const value : IExternalSymbolHandler);

      public
         procedure Add(const item : IExternalSymbolHandler);
         procedure Extract(idx : Integer);
         procedure Clear;
         procedure Enumerate(const callback : TSimpleCallbackIExternalSymbolHandler);
         property Items[const position : Integer] : IExternalSymbolHandler read GetItems write SetItems; default;
         property Count : Integer read FCount;
   end;

   TSymbolHandlers = class (TRefCountedObject)
      FSymbol : TSymbol;
      FHandlers : TSimpleListIExternalSymbolHandler;
      destructor Destroy; override;
   end;

   TSimpleCallbackSymbolHandlers = function (var item : TSymbolHandlers) : TSimpleCallbackStatus;

   // TSymbolHandlersList
   //
   TSymbolHandlersList = class
      private
         type
            TArrayOfSymbolHandlers = array of TSymbolHandlers;
         var
            FItems : TArrayOfSymbolHandlers;
            FCount : Integer;

      protected
         function GetItem(index : Integer) : TSymbolHandlers;
         function Find(const item : TSymbolHandlers; var index : Integer) : Boolean; overload;
         function Find(symbol : TSymbol) : TSymbolHandlers; overload;
         function Compare(const item1, item2 : TSymbolHandlers) : Integer;
         procedure InsertItem(index : Integer; const anItem : TSymbolHandlers);

      public
         function Add(const anItem : TSymbolHandlers) : Integer;
         function AddOrFind(const anItem : TSymbolHandlers; var added : Boolean) : Integer;
         function Extract(const anItem : TSymbolHandlers) : Integer;
         function ExtractAt(index : Integer) : TSymbolHandlers;
         function IndexOf(const anItem : TSymbolHandlers) : Integer;
         procedure Clear;
         procedure Clean;
         procedure Enumerate(const callback : TSimpleCallbackSymbolHandlers);
         property Items[index : Integer] : TSymbolHandlers read GetItem; default;
         property Count : Integer read FCount;
   end;

var
   vSearch : TSymbolHandlers;
   vRegisteredHandlers : TSymbolHandlersList;

// ------------------
// ------------------ TSimpleListIExternalSymbolHandler ------------------
// ------------------

// Add
//
procedure TSimpleListIExternalSymbolHandler.Add(const item : IExternalSymbolHandler);
begin
   if FCount=FCapacity then Grow;
   FItems[FCount]:=item;
   Inc(FCount);
end;

// Extract
//
procedure TSimpleListIExternalSymbolHandler.Extract(idx : Integer);
var
   n : Integer;
begin
   FItems[idx]:=Default(IExternalSymbolHandler);
   n:=FCount-idx-1;
   if n>0 then begin
      Move(FItems[idx+1], FItems[idx], n*SizeOf(IExternalSymbolHandler));
      FillChar(FItems[FCount-1], SizeOf(IExternalSymbolHandler), 0);
   end;
   Dec(FCount);
end;

// Clear
//
procedure TSimpleListIExternalSymbolHandler.Clear;
begin
   SetLength(FItems, 0);
   FCapacity:=0;
   FCount:=0;
end;

// Enumerate
//
procedure TSimpleListIExternalSymbolHandler.Enumerate(const callback : TSimpleCallbackIExternalSymbolHandler);
var
   i : Integer;
begin
   for i:=0 to Count-1 do
      if callBack(FItems[i])=csAbort then
         Break;
end;

// Grow
//
procedure TSimpleListIExternalSymbolHandler.Grow;
begin
   FCapacity:=FCapacity+8+(FCapacity shr 2);
   SetLength(FItems, FCapacity);
end;

// GetItems
//
function TSimpleListIExternalSymbolHandler.GetItems(const idx : Integer) : IExternalSymbolHandler;
begin
   Result:=FItems[idx];
end;

// SetItems
//
procedure TSimpleListIExternalSymbolHandler.SetItems(const idx : Integer; const value : IExternalSymbolHandler);
begin
   FItems[idx]:=value;
end;

// ------------------
// ------------------ TSymbolHandlers ------------------
// ------------------

// Destroy
//
destructor TSymbolHandlers.Destroy;
begin
   inherited;
   FHandlers.Free;
end;

// ------------------
// ------------------ TSymbolHandlersList ------------------
// ------------------

// Compare
//
function TSymbolHandlersList.Compare(const item1, item2 : TSymbolHandlers) : Integer;
begin
   if NativeUInt(item1.FSymbol)>NativeUInt(item2.FSymbol) then
      Result:=1
   else if NativeUInt(item1.FSymbol)<NativeUInt(item2.FSymbol) then
      Result:=-1
   else Result:=0;
end;

// Find
//
function TSymbolHandlersList.Find(symbol : TSymbol) : TSymbolHandlers;
var
   lo, hi, mid : Integer;
begin
   lo:=0;
   hi:=Count-1;
   while lo<=hi do begin
      mid:=(lo+hi) shr 1;
      Result:=GetItem(mid);
      if NativeUInt(Result.FSymbol)<NativeUInt(symbol) then
         lo:=mid+1
      else begin
         hi:=mid- 1;
         if NativeUInt(Result.FSymbol)=NativeUInt(symbol) then
            Exit;
      end;
   end;
   Result:=nil;
end;

// ------------------
// ------------------ TExternalSymbolHandler ------------------
// ------------------

// Assign
//
procedure TExternalSymbolHandler.Assign(exec : TdwsExecution; symbol : TDataSymbol; expr : TTypedExpr; var handled : Boolean);
begin
   handled:=False;
end;

// Eval
//
procedure TExternalSymbolHandler.Eval(exec : TdwsExecution; symbol : TDataSymbol; var handled : Boolean; var result : Variant);
begin
   handled:=False;
end;

// Register
//
class procedure TExternalSymbolHandler.Register(symbol : TSymbol; const handler : IExternalSymbolHandler);
var
   i : Integer;
   h : TSymbolHandlers;
begin
   h:=TSymbolHandlers.Create;
   h.FSymbol:=symbol;
   i:=vRegisteredHandlers.IndexOf(h);
   if i>=0 then begin
      h.Free;
      h:=vRegisteredHandlers[i];
   end else begin
      vRegisteredHandlers.Add(h);
      h.FHandlers:=TSimpleListIExternalSymbolHandler.Create;
   end;
   h.FHandlers.Add(handler);
end;

// HandleAssign
//
class procedure TExternalSymbolHandler.HandleAssign(exec : TdwsExecution; symbol : TDataSymbol; expr : TTypedExpr; var handled : Boolean);
var
   h : TSymbolHandlers;
   i : Integer;
begin
   h:=vRegisteredHandlers.Find(symbol);
   if h<>nil then begin
      for i:=0 to h.FHandlers.Count-1 do begin
         h.FHandlers[i].Assign(exec, symbol, expr, handled);
         if handled then exit;
      end;
   end else begin
      handled:=False;
   end;
end;

// HandleEval
//
class procedure TExternalSymbolHandler.HandleEval(exec : TdwsExecution; symbol : TDataSymbol; var handled : Boolean; var result : Variant);
var
   h : TSymbolHandlers;
   i : Integer;
begin
   h:=vRegisteredHandlers.Find(symbol);
   if h<>nil then begin
      for i:=0 to h.FHandlers.Count-1 do begin
         h.FHandlers[i].Eval(exec, symbol, handled, result);
         if handled then exit;
      end;
   end else begin
      handled:=False;
   end;
end;

// ------------------
// ------------------ TSymbolHandlersList ------------------
// ------------------

// GetItem
//
function TSymbolHandlersList.GetItem(index : Integer) : TSymbolHandlers;
begin
   Result:=FItems[index];
end;

// Find
//
function TSymbolHandlersList.Find(const item : TSymbolHandlers; var index : Integer) : Boolean;
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
procedure TSymbolHandlersList.InsertItem(index : Integer; const anItem : TSymbolHandlers);
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
function TSymbolHandlersList.Add(const anItem : TSymbolHandlers) : Integer;
begin
   Find(anItem, Result);
   InsertItem(Result, anItem);
end;

// AddOrFind
//
function TSymbolHandlersList.AddOrFind(const anItem : TSymbolHandlers; var added : Boolean) : Integer;
begin
   added:=not Find(anItem, Result);
   if added then
      InsertItem(Result, anItem);
end;

// Extract
//
function TSymbolHandlersList.Extract(const anItem : TSymbolHandlers) : Integer;
begin
   if Find(anItem, Result) then
      ExtractAt(Result)
   else Result:=-1;
end;

// ExtractAt
//
function TSymbolHandlersList.ExtractAt(index : Integer) : TSymbolHandlers;
var
   n : Integer;
begin
   Dec(FCount);
   Result:=FItems[index];
   n:=FCount-index;
   if n>0 then
      System.Move(FItems[index+1], FItems[index], n*SizeOf(TSymbolHandlers));
   SetLength(FItems, FCount);
end;

// IndexOf
//
function TSymbolHandlersList.IndexOf(const anItem : TSymbolHandlers) : Integer;
begin
   if not Find(anItem, Result) then
      Result:=-1;
end;

// Clear
//
procedure TSymbolHandlersList.Clear;
begin
   SetLength(FItems, 0);
   FCount:=0;
end;

// Clean
//
procedure TSymbolHandlersList.Clean;
var
   i : Integer;
begin
   for i:=0 to FCount-1 do
      FItems[i].Free;
   Clear;
end;

// Enumerate
//
procedure TSymbolHandlersList.Enumerate(const callback : TSimpleCallbackSymbolHandlers);
var
   i : Integer;
begin
   for i:=0 to Count-1 do
      if callback(FItems[i])=csAbort then
         Break;
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

   vRegisteredHandlers:=TSymbolHandlersList.Create;
   vSearch:=TSymbolHandlers.Create;

finalization

   vSearch.Free;
   vRegisteredHandlers.Clean;
   vRegisteredHandlers.Free;

end.
