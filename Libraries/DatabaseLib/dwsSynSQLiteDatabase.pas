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
{    Copyright Creative IT.                                            }
{    Current maintainer: Eric Grange                                   }
{                                                                      }
{**********************************************************************}
{
    This unit wraps SynSQLite3 from Synopse mORMot framework.

    Synopse mORMot framework. Copyright (C) 2012 Arnaud Bouchez
      Synopse Informatique - http://synopse.info
}
unit dwsSynSQLiteDatabase;

interface

uses
   Classes, Variants, SysUtils,
   SynSQLite3, SynCommons,
   dwsUtils, dwsExprs, dwsDatabase, dwsStack, dwsXPlatform, dwsDataContext, dwsSymbols;

type
   TdwsSynSQLiteDataSet = class;

   TdwsSynSQLiteDataBase = class (TdwsDataBase, IdwsDataBase)
      private
         FDB : TSQLDatabase;
         FDataSets : Integer;
         FExecRequest : TSQLRequest;
         FExecSQL : String;
         FModules : TStringList;

      protected
         function GetModule(const name : String) : TObject;
         procedure SetModule(const name : String; aModule : TObject);

      public
         constructor Create(const parameters : array of String);
         destructor Destroy; override;

         procedure BeginTransaction;
         procedure Commit;
         procedure Rollback;
         function InTransaction : Boolean;
         function CanReleaseToPool : String;

         procedure Exec(const sql : String; const parameters : TData; context : TExprBase);
         function Query(const sql : String; const parameters : TData; context : TExprBase) : IdwsDataSet;

         function VersionInfoText : String;

         property DB : TSQLDatabase read FDB;
         property Module[const name : String] : TObject read GetModule write SetModule;
   end;

   TdwsSynSQLiteDataSet = class (TdwsDataSet)
      private
         FDB : TdwsSynSQLiteDataBase;
         FRequest : TSQLRequest;
         FEOFReached : Boolean;
         FSQL : String;

      protected
         procedure DoPrepareFields; override;

      public
         constructor Create(db : TdwsSynSQLiteDataBase; const sql : String; const parameters : TData);
         destructor Destroy; override;

         function Eof : Boolean; override;
         procedure Next; override;

         function FieldCount : Integer; override;

         property SQL : String read FSQL;
   end;

   TdwsSynSQLiteDataField = class (TdwsDataField)
      private
         FDataSet : TdwsSynSQLiteDataSet;

      protected
         function GetName : String; override;
         function GetDataType : TdwsDataFieldType; override;
         function GetDeclaredType : String; override;

      public
         constructor Create(dataSet : TdwsSynSQLiteDataSet; fieldIndex : Integer);

         function DataType : TdwsDataFieldType; override;

         function IsNull : Boolean; override;
         function AsString : String; override;
         function AsInteger : Int64; override;
         function AsFloat : Double; override;
         function AsBlob : RawByteString; override;
   end;

//   IdwsBlob = interface
//      ['{018C9441-3177-49E1-97EF-EA5F2584FA60}']
//   end;

   TdwsSynSQLiteDataBaseFactory = class (TdwsDataBaseFactory)
      public
         function CreateDataBase(const parameters : TStringDynArray) : IdwsDataBase; override;
   end;

var
   vOnNeedSQLite3DynamicDLLName : function : String;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

var
   vSQLite3DynamicMRSW : TMultiReadSingleWrite;

procedure InitializeSQLite3Dynamic;

   procedure DoInitialize;
   var
      dllName : String;
   begin
      vSQLite3DynamicMRSW.BeginWrite;
      try
         if sqlite3=nil then begin
            if Assigned(vOnNeedSQLite3DynamicDLLName) then
               dllName:=vOnNeedSQLite3DynamicDLLName;
            if dllName<>'' then
               sqlite3:=TSQLite3LibraryDynamic.Create(dllName)
            else sqlite3:=TSQLite3LibraryDynamic.Create;
         end;
      finally
         vSQLite3DynamicMRSW.EndWrite;
      end;
   end;

begin
   vSQLite3DynamicMRSW.BeginRead;
   try
      if sqlite3<>nil then Exit;
   finally
      vSQLite3DynamicMRSW.EndRead;
   end;
   DoInitialize;
end;

function SQLiteTypeToDataType(sqliteType : Integer) : TdwsDataFieldType;
const
   cSQLiteTypeToDataType : array [SQLITE_INTEGER..SQLITE_NULL] of TdwsDataFieldType = (
      dftInteger, dftFloat, dftString, dftBlob, dftNull
   );
begin
   Assert(sqliteType in [Low(cSQLiteTypeToDataType)..High(SQLITE_NULL)]);
   Result:=cSQLiteTypeToDataType[sqliteType]
end;

// SQLAssignParameters
//
procedure SQLAssignParameters(var rq : TSQLRequest; const params : TData);

   procedure BindDateTime(var rq : TSQLRequest; i : Integer; p : PVarData);
   var
      dtStr : String;
   begin
      dtStr:=DateTimeToISO8601(p.VDate, True);
      rq.BindS(i, dtStr);
   end;

var
   i : Integer;
   p : PVarData;
begin
   for i:=1 to Length(params) do begin
      p:=PVarData(@params[i-1]);
      case p.VType of
         varInt64 : rq.Bind(i, p.VInt64);
         varDouble : rq.Bind(i, p.VDouble);
         varUString : rq.BindS(i, String(p.VUString));
         varBoolean : rq.Bind(i, Ord(p.VBoolean));
         varNull : rq.BindNull(i);
         varString : rq.Bind(i, p.VString, Length(RawByteString(p.VString)));
         varDate : BindDateTime(rq, i, p);
      else
         raise Exception.CreateFmt('Unsupported VarType %d', [p.VType]);
      end;
   end;
end;

// ------------------
// ------------------ TdwsSynSQLiteDataBaseFactory ------------------
// ------------------

// CreateDataBase
//
function TdwsSynSQLiteDataBaseFactory.CreateDataBase(const parameters : TStringDynArray) : IdwsDataBase;
var
   db : TdwsSynSQLiteDataBase;
begin
   if sqlite3=nil then
      InitializeSQLite3Dynamic;
   db:=TdwsSynSQLiteDataBase.Create(parameters);
   Result:=db;
end;

// ------------------
// ------------------ TdwsSynSQLiteDataBase ------------------
// ------------------

// Create
//
constructor TdwsSynSQLiteDataBase.Create(const parameters : array of String);
var
   dbName : String;
   i, flags : Integer;
begin
   if Length(parameters)>0 then
      dbName:=TdwsDataBase.ApplyPathVariables(parameters[0])
   else dbName:=':memory:';

   flags:=SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE;
   for i:=1 to High(parameters) do begin
      if UnicodeSameText(parameters[i], 'read_only') then
         flags:=SQLITE_OPEN_READONLY
      else if UnicodeSameText(parameters[i], 'shared_cache') then
         flags:=flags or SQLITE_OPEN_SHAREDCACHE
      else if UnicodeSameText(parameters[i], 'open_uri') then
         flags:=flags or SQLITE_OPEN_URI;
   end;

   try
      FDB:=TSQLDatabase.Create(dbName, '', flags);
      FDB.BusyTimeout:=1500;
   except
      RefCount:=0;
      raise;
   end;
end;

// Destroy
//
destructor TdwsSynSQLiteDataBase.Destroy;
begin
   FModules.Free;
   FExecRequest.Close;
   FDB.Free;
   inherited;
end;

// BeginTransaction
//
procedure TdwsSynSQLiteDataBase.BeginTransaction;
begin
   FDB.TransactionBegin;
end;

// Commit
//
procedure TdwsSynSQLiteDataBase.Commit;
begin
   FDB.Commit;
end;

// Rollback
//
procedure TdwsSynSQLiteDataBase.Rollback;
begin
   FDB.Rollback;
end;

// InTransaction
//
function TdwsSynSQLiteDataBase.InTransaction : Boolean;
begin
   Result:=FDB.TransactionActive;
end;

// CanReleaseToPool
//
function TdwsSynSQLiteDataBase.CanReleaseToPool : String;
begin
   if FDB.TransactionActive then
      Result:='in transaction'
   else if FDataSets>0 then  // need to check as they could maintain a lock
      Result:='has opened datasets'
   else begin
      FExecRequest.Close;
      Result:='';
   end;
end;

// Exec
//
procedure TdwsSynSQLiteDataBase.Exec(const sql : String; const parameters : TData; context : TExprBase);
var
   err : Integer;
begin
   if sql='' then
      raise ESQLite3Exception.CreateFmt('Empty query', []);
   if FExecRequest.Request<>0 then begin
      if FExecSQL<>sql then
         FExecRequest.Close;
   end;
   if FExecRequest.Request=0 then begin
      FExecRequest.Prepare(FDB.DB, StringToUTF8(sql));
      FExecSQL:=sql;
   end;
   try
      SQLAssignParameters(FExecRequest, parameters);
      while FExecRequest.Step=SQLITE_ROW do ;
      err := FExecRequest.Reset;
      if err <> SQLITE_OK then
         raise Exception.CreateFmt('Statement Reset failed (%d)', [err]);
      FExecRequest.BindReset;
   except
      FExecRequest.Close;
      raise;
   end;
end;

// Query
//
function TdwsSynSQLiteDataBase.Query(const sql : String; const parameters : TData; context : TExprBase) : IdwsDataSet;
var
   ds : TdwsSynSQLiteDataSet;
begin
   if sql='' then
      raise ESQLite3Exception.CreateFmt('Empty query', []);
   ds:=TdwsSynSQLiteDataSet.Create(Self, sql, parameters);
   Result:=ds;
end;

// VersionInfoText
//
function TdwsSynSQLiteDataBase.VersionInfoText : String;
begin
   Result:=UTF8ToString(sqlite3.libversion);
end;

// GetModule
//
function TdwsSynSQLiteDataBase.GetModule(const name : String) : TObject;
var
   i : Integer;
begin
   Result := nil;
   if FModules <> nil then begin
      i := FModules.IndexOf(name);
      if i >= 0 then
         Result := FModules.Objects[i];
   end;
end;

// SetModule
//
procedure TdwsSynSQLiteDataBase.SetModule(const name : String; aModule : TObject);
begin
   if FModules = nil then begin
      FModules := TFastCompareStringList.Create;
      FModules.Sorted := True;
   end else if FModules.IndexOf(name) >= 0 then
      raise Exception.CreateFmt('Module "%s" already registered', [name]);
   FModules.AddObject(name, aModule);
end;

// ------------------
// ------------------ TdwsSynSQLiteDataSet ------------------
// ------------------

// Create
//
constructor TdwsSynSQLiteDataSet.Create(db : TdwsSynSQLiteDataBase; const sql : String; const parameters : TData);
begin
   FSQL:=sql;
   FDB:=db;
   inherited Create(db);
   try
      FRequest.Prepare(db.FDB.DB, StringToUTF8(sql));
      try
         Assert(FRequest.Request<>0);
         SQLAssignParameters(FRequest, parameters);
         FEOFReached:=(FRequest.Step=SQLITE_DONE);
         Inc(FDB.FDataSets);
      except
         FRequest.Close;
         raise;
      end;
   except
      RefCount:=0;
      raise;
   end;
end;

// Destroy
//
destructor TdwsSynSQLiteDataSet.Destroy;
begin
   Dec(FDB.FDataSets);
   FRequest.Close;
   inherited;
end;

// Eof
//
function TdwsSynSQLiteDataSet.Eof : Boolean;
begin
   Result:=FEOFReached;
end;

// Next
//
procedure TdwsSynSQLiteDataSet.Next;
begin
   FEOFReached:=(FRequest.Step=SQLITE_DONE);
end;

// FieldCount
//
function TdwsSynSQLiteDataSet.FieldCount : Integer;
begin
   Result:=FRequest.FieldCount;
end;

// DoPrepareFields
//
procedure TdwsSynSQLiteDataSet.DoPrepareFields;
var
   i, n : Integer;
begin
   n:=FRequest.FieldCount;
   SetLength(FFields, n);
   for i:=0 to n-1 do
      FFields[i]:=TdwsSynSQLiteDataField.Create(Self, i);
end;

// ------------------
// ------------------ TdwsSynSQLiteDataField ------------------
// ------------------

// Create
//
constructor TdwsSynSQLiteDataField.Create(dataSet : TdwsSynSQLiteDataSet; fieldIndex : Integer);
begin
   FDataSet:=dataSet;
   inherited Create(dataSet, fieldIndex);
end;

// DataType
//
function TdwsSynSQLiteDataField.DataType : TdwsDataFieldType;
begin
   Result:=GetDataType;
end;

// IsNull
//
function TdwsSynSQLiteDataField.IsNull : Boolean;
begin
   if FDataSet.FEOFReached then
      RaiseNoActiveRecord;
   Result:=TdwsSynSQLiteDataSet(DataSet).FRequest.FieldNull(Index);
end;

// GetName
//
function TdwsSynSQLiteDataField.GetName : String;
begin
   Result:=UTF8ToString(TdwsSynSQLiteDataSet(DataSet).FRequest.FieldName(Index));
end;

// GetDataType
//
function TdwsSynSQLiteDataField.GetDataType : TdwsDataFieldType;
begin
   Result:=SQLiteTypeToDataType(TdwsSynSQLiteDataSet(DataSet).FRequest.FieldType(Index));
end;

// GetDeclaredType
//
function TdwsSynSQLiteDataField.GetDeclaredType : String;
begin
   Result:=TdwsSynSQLiteDataSet(DataSet).FRequest.FieldDeclaredTypeS(Index);
end;

// AsString
//
function TdwsSynSQLiteDataField.AsString : String;
begin
   if FDataSet.FEOFReached then
      RaiseNoActiveRecord;
   Result:=TdwsSynSQLiteDataSet(DataSet).FRequest.FieldS(Index);
end;

// AsInteger
//
function TdwsSynSQLiteDataField.AsInteger : Int64;
begin
   if FDataSet.FEOFReached then
      RaiseNoActiveRecord;
   Result:=TdwsSynSQLiteDataSet(DataSet).FRequest.FieldInt(Index);
end;

// AsFloat
//
function TdwsSynSQLiteDataField.AsFloat : Double;
begin
   if FDataSet.FEOFReached then
      RaiseNoActiveRecord;
   Result:=TdwsSynSQLiteDataSet(DataSet).FRequest.FieldDouble(Index);
end;

// AsBlob
//
function TdwsSynSQLiteDataField.AsBlob : RawByteString;
begin
   if FDataSet.FEOFReached then
      RaiseNoActiveRecord;
   Result:=TdwsSynSQLiteDataSet(DataSet).FRequest.FieldBlob(Index);
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

   TdwsDatabase.RegisterDriver('SQLite', TdwsSynSQLiteDataBaseFactory.Create);

   vSQLite3DynamicMRSW:=TMultiReadSingleWrite.Create;

finalization

   FreeAndNil(vSQLite3DynamicMRSW);

end.
