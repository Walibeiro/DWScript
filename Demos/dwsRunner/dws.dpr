program dws;

{$SetPEFlags $0001}

{$IFNDEF VER200} // delphi 2009
{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$ENDIF}
{$APPTYPE CONSOLE}

{$r *.dres}

uses
  Windows,
  Classes,
  SysUtils,
  dwsXPlatform in '..\..\Source\dwsXPlatform.pas',
  dwsComp in '..\..\Source\dwsComp.pas',
  dwsCompiler in '..\..\Source\dwsCompiler.pas',
  dwsExprs in '..\..\Source\dwsExprs.pas',
  dwsUtils in '..\..\Source\dwsUtils.pas',
  dwsFunctions in '..\..\Source\dwsFunctions.pas',
  dwsStrings in '..\..\Source\dwsStrings.pas',
  dwsErrors in '..\..\Source\dwsErrors.pas',
  dwsSymbols in '..\..\Source\dwsSymbols.pas',
  dwsJSON in '..\..\Source\dwsJSON.pas',
  dwsDateTime in '..\..\Source\dwsDateTime.pas',
  dwsTokenizer in '..\..\Source\dwsTokenizer.pas',
  dwsStack in '..\..\Source\dwsStack.pas',
  dwsDataContext in '..\..\Source\dwsDataContext.pas',
  dwsExprList in '..\..\Source\dwsExprList.pas',
  dwsUnitSymbols in '..\..\Source\dwsUnitSymbols.pas',
  dwsOperators in '..\..\Source\dwsOperators.pas',
  dwsCoreExprs in '..\..\Source\dwsCoreExprs.pas',
  dwsConvExprs in '..\..\Source\dwsConvExprs.pas',
  dwsConstExprs in '..\..\Source\dwsConstExprs.pas',
  dwsCompilerUtils in '..\..\Source\dwsCompilerUtils.pas',
  dwsMethodExprs in '..\..\Source\dwsMethodExprs.pas',
  dwsMagicExprs in '..\..\Source\dwsMagicExprs.pas',
  dwsExternalSymbols in '..\..\Source\dwsExternalSymbols.pas',
  dwsInfo in '..\..\Source\dwsInfo.pas',
  dwsConnectorSymbols in '..\..\Source\dwsConnectorSymbols.pas',
  dwsConnectorExprs in '..\..\Source\dwsConnectorExprs.pas',
  dwsResultFunctions in '..\..\Source\dwsResultFunctions.pas',
  dwsRelExprs in '..\..\Source\dwsRelExprs.pas',
  dwsSetOfExprs in '..\..\Source\dwsSetOfExprs.pas',
  dwsPascalTokenizer in '..\..\Source\dwsPascalTokenizer.pas',
  dwsSystemOperators in '..\..\Source\dwsSystemOperators.pas',
  dwsLanguageExtension in '..\..\Source\dwsLanguageExtension.pas',
  dwsMathFunctions in '..\..\Source\dwsMathFunctions.pas',
  dwsStringFunctions in '..\..\Source\dwsStringFunctions.pas',
  dwsTimeFunctions in '..\..\Source\dwsTimeFunctions.pas',
  dwsVariantFunctions in '..\..\Source\dwsVariantFunctions.pas',
  dwsFileFunctions in '..\..\Source\dwsFileFunctions.pas',
  dwsFileSystem in '..\..\Source\dwsFileSystem.pas',
  dwsEncoding in '..\..\Source\dwsEncoding.pas',
  dwsWebUtils in '..\..\Source\dwsWebUtils.pas',
  dwsWebServerUtils in '..\..\Source\dwsWebServerUtils.pas',
  dwsClasses in '..\..\Libraries\ClassesLib\dwsClasses.pas',
  dwsClassesLibModule in '..\..\Libraries\ClassesLib\dwsClassesLibModule.pas',
  dwsHashtables in '..\..\Libraries\ClassesLib\dwsHashtables.pas',
  dwsZipLibModule in '..\..\Libraries\ClassesLib\dwsZipLibModule.pas',
  dwsEncodingLibModule in '..\..\Libraries\ClassesLib\dwsEncodingLibModule.pas',
(*
  dwsBigIntegerFunctions.GMP in '..\..\Libraries\BigIntegersLib\dwsBigIntegerFunctions.pas',
  dwsMPIR.Bundle in '..\..\Libraries\BigIntegersLib\dwsMPIR.pas',
  dwsCryptoLibModule in '..\..\Libraries\CryptoLib\dwsCryptoLibModule.pas',
  dwsCryptoXPlatform in '..\..\Source\dwsCryptoXPlatform.pas',
  dwsTokenStore in '..\..\Libraries\CryptoLib\dwsTokenStore.pas',
  dwsWebLibModule in '..\..\Libraries\SimpleServer\dwsWebLibModule.pas',
  dwsDatabaseLibModule in '..\..\Libraries\DatabaseLib\dwsDatabaseLibModule.pas',
  dwsDatabase in '..\..\Libraries\DatabaseLib\dwsDatabase.pas',
  dwsSynSQLiteDatabase in '..\..\Libraries\dwsSynSQLiteDatabase.pas',
*)
  dwsComConnector in '..\..\Source\dwsComConnector.pas',
  dwsJSONConnector in '..\..\Source\dwsJSONConnector.pas',
  dwsRunnerProject in 'dwsRunnerProject.pas',
  SynZip;

{$SetPEFlags IMAGE_FILE_LARGE_ADDRESS_AWARE or IMAGE_FILE_RELOCS_STRIPPED}

function CreateScript : TDelphiWebScript;
begin
   Result:=TDelphiWebScript.Create(nil);

   TdwsComConnector.Create(Result).Script:=Result;
   TdwsJSONLibModule.Create(Result).Script:=Result;
   TdwsClassesLib.Create(Result).dwsUnit.Script:=Result;
   TdwsEncodingLib.Create(Result).dwsEncoding.Script:=Result;
(*
   TdwsCryptoLib.Create(Result).dwsCrypto.Script:=Result;
   TdwsDatabaseLib.Create(Result).dwsDatabase.Script:=Result;
   TdwsWebLib.Create(Result).dwsWeb.Script:=Result;
*)
   TdwsZipLib.Create(Result).dwsZip.Script:=Result;
end;

procedure WriteHeader;
begin
   Writeln('dws Runner - sample code runner for DWScript');
   Writeln('');
end;

{$WARN SYMBOL_PLATFORM OFF}

procedure MakeExe;
var
   zw : TZipWrite;
   sourceName, zipFileName, exeName : String;
   hUpdate : THandle;
   buf : RawByteString;
   fs : TFileStream;
   zip : TZipProject;
   prog : IdwsProgram;
   script : TDelphiWebScript;
   searchRec : TSearchRec;
   found : Integer;
begin
   WriteHeader;

   if ParamCount<2 then begin
      Writeln('Missing zipfile name');
      Exit;
   end;

   sourceName:=ParamStr(2);
   WriteLn('...Starting make for "', sourceName, '"');

   if not StrEndsWith(sourceName, '.zip') then begin
      zipFileName:=ChangeFileExt(sourceName, '.zip');
      WriteLn('...Zipping to "', zipFileName, '"');
      zw:=TZipWrite.Create(zipFileName);
      try
         if DirectoryExists(sourceName) then begin
            sourceName:=IncludeTrailingPathDelimiter(sourceName);
            found:=FindFirst(sourceName+'*.*', faArchive or faReadOnly, searchRec);
            while found=0 do begin
               zw.AddDeflated(sourceName+searchRec.Name, True, 9);
               found:=FindNext(searchRec);
            end;
            FindClose(searchRec);
         end else zw.AddDeflated(sourceName, True, 9);
      finally
         zw.Free;
      end;
   end else begin
      zipFileName:=sourceName;
   end;
   if ParamCount>2 then
      exeName:=ParamStr(3)
   else exeName:=ChangeFileExt(zipFileName, '.exe');

   zip:=TZipProject.Create(zipFileName);
   script:=CreateScript;
   try
      prog:=script.Compile(zip.Attach(script));
      try
         if prog.Msgs.Count>0 then begin
            WriteLn('...Compiled with ', prog.Msgs.Count, ' message(s):');
            WriteLn(prog.Msgs.AsInfo);
            if prog.Msgs.HasErrors then begin
               Write('...Generation aborted');
               Exit;
            end;
         end else begin
            WriteLn('...Compiled without errors.');
         end;
      finally
         prog:=nil;
      end;
   finally
      script.Free;
      zip.Free;
   end;

   if not FileCopy(ParamStr(0), exeName, False) then begin
      Writeln('...Failed to create "', exeName, '"');
   end;

   fs:=TFileStream.Create(zipFileName, fmOpenRead or fmShareDenyNone);
   try
      SetLength(buf, fs.Size);
      if Length(buf)<>0 then
         fs.Read(buf[1], Length(buf));
   finally
      fs.Free;
   end;

   hUpdate:=BeginUpdateResource(PChar(exeName), False);
   try
      UpdateResource(hUpdate, RT_RCDATA, 'SCRIPT', 0, Pointer(buf), Length(buf));
   finally
      EndUpdateResource(hUpdate, False);
   end;

   WriteLn('..."', exeName, '" generated successfully!');
end;

var
   fileName : String;
   source : String;
   script : TDelphiWebScript;
   prog : IdwsProgram;
   exec : IdwsProgramExecution;
   i, paramOffset : Integer;
   params : array of Variant;
   project : TRunnerProject;
   zr : TZipRead;
   embedded : Boolean;
begin
   zr:=TZipRead.Create(HInstance, 'SCRIPT', RT_RCDATA);
   if zr.Count=0 then begin
      FreeAndNil(zr);
      project:=nil;
      paramOffset:=2;
      embedded:=False;
   end else begin
      project:=TZipProject.Create(zr);
      paramOffset:=1;
      embedded:=True;
   end;

   if project=nil then begin
      if ParamCount<1 then begin
         WriteHeader;
         Writeln('Run a simple script with:');
         Writeln('   dws <sourcefile> [param1] [param2] ... [paramN]');
         Writeln('');
         Writeln('Run a zip project with (starts from "main.pas" in the zip):');
         Writeln('   dws <zipfile> [param1] [param2] ... [paramN]');
         Writeln('');
         Writeln('Bundle a zip project into an executable:');
         Writeln('   dws make <zipFile|sourcefile> [exeName]');
         Exit;
      end;
      fileName:=ParamStr(1);
      if fileName='make' then begin
         MakeExe;
         exit;
      end;
      if FileExists(fileName) then
         if StrEndsWith(fileName, '.zip') then
            project:=TZipProject.Create(fileName)
         else project:=TFileProject.Create(fileName)
      else if DirectoryExists(fileName) then
         project:=TDirectoryProject.Create(fileName)
      else begin
         Writeln('File "', fileName, '" not found.');
         Exit;
      end;
   end;
   try
      script:=CreateScript;
      try
         source:=project.Attach(script);

         prog:=script.Compile(source);

         if prog.Msgs.Count>0 then begin
            if prog.Msgs.HasErrors or not embedded then
               Writeln(prog.Msgs.AsInfo);
            if prog.Msgs.HasErrors then Exit;
         end;

         SetLength(params, ParamCount-paramOffset+2);
         params[0]:=ParamStr(0);
         for i:=paramOffset to ParamCount do
            params[i-paramOffset+1]:=ParamStr(i);
         exec:=prog.ExecuteParam(params);
         Writeln(exec.Result.ToString);
         if exec.Msgs.Count>0 then
            Writeln(exec.Msgs.AsInfo);
      finally
         project.Free;
         script.Free;
      end;
   except
      on E: Exception do
         Writeln(E.ClassName, ': ', E.Message);
   end;
end.
