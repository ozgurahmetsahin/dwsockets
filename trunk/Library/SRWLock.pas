unit SRWLock;

interface

uses
  Windows;

type
  //Copied from system.SyncObjs
  TWaitResult = (wrSignaled, wrTimeout, wrAbandoned, wrError, wrIOCompletion);

  TInitializeConditionVariable = function (out ConditionVariable: Pointer): NativeUInt; stdcall;
  TSleepConditionVariableSRW = function (var ConditionalVariableSRW: Pointer; var SRWLock: Pointer; dwMilliseconds: DWORD; Flags: ULONG): BOOL; stdcall;

  TWakeConditionVariable = function (var ConditionVariable: Pointer): NativeUInt; stdcall;
  TWakeAllConditionVariable = function (var ConditionVariable: Pointer): NativeUInt; stdcall;

  TInitializeSRWLock = function (out P: Pointer): NativeUInt; stdcall;

  TAcquireSRWLockShared = function (var P: Pointer): NativeUInt; stdcall;
  TReleaseSRWLockShared = function (var P: Pointer): NativeUInt; stdcall;

  TAcquireSRWLockExclusive = function (var P: Pointer): NativeUInt; stdcall;
  TReleaseSRWLockExclusive = function (var P: Pointer): NativeUInt; stdcall;

  TTryAcquireSRWLockExclusive = function (var P: Pointer): BOOL; stdcall;
  TTryAcquireSRWLockShared = function (var P: Pointer): BOOL; stdcall;

  // The slim reader/writer (SRW) lock enables the threads of a single process to access shared resources.
  // It is optimized for speed and occupies very little memory.

  TSRWLock = class
  protected
    fHandle: Pointer;

    CallInitializeSRWLock: TInitializeSRWLock;

    CallAcquireSRWLockShared: TAcquireSRWLockShared;
    CallReleaseSRWLockShared: TReleaseSRWLockShared;

    CallAcquireSRWLockExclusive: TAcquireSRWLockExclusive;
    CallReleaseSRWLockExclusive: TReleaseSRWLockExclusive;

    CallTryAcquireSRWLockExclusive: TTryAcquireSRWLockExclusive;
    CallTryAcquireSRWLockShared: TTryAcquireSRWLockShared;
  public
    constructor Create;

    procedure AcquireShared; inline;
    procedure ReleaseShared; inline;
    procedure AcquireExclusive; inline;
    procedure ReleaseExclusive; inline;

    function TryAcquireShared: Boolean; inline;
    function TryAcquireExclusive: Boolean; inline;
  end;

  TConditionVariable = class
  protected
    fHandle: Pointer;

    CallInitializeConditionVariable: TInitializeConditionVariable;
    CallSleepConditionVariableSRW: TSleepConditionVariableSRW;

    CallWakeConditionVariable: TWakeConditionVariable;
    CallWakeAllConditionVariable: TWakeAllConditionVariable;
  public
    constructor Create;

    function WaitFor(aSRWLock: TSRWLock; aTimeOut: Cardinal = INFINITE): TWaitResult; inline;
    procedure Release; inline;
    procedure ReleaseAll; inline;
  end;

implementation

var
  _InitializeConditionVariable: TInitializeConditionVariable;
  _SleepConditionVariableSRW: TSleepConditionVariableSRW;

  _WakeConditionVariable: TWakeConditionVariable;
  _WakeAllConditionVariable: TWakeAllConditionVariable;

  _InitializeSRWLock: TInitializeSRWLock;

  _AcquireSRWLockShared: TAcquireSRWLockShared;
  _ReleaseSRWLockShared: TReleaseSRWLockShared;

  _AcquireSRWLockExclusive: TAcquireSRWLockExclusive;
  _ReleaseSRWLockExclusive: TReleaseSRWLockExclusive;

  _TryAcquireSRWLockExclusive: TTryAcquireSRWLockExclusive;
  _TryAcquireSRWLockShared: TTryAcquireSRWLockShared;

procedure InitializeConditionVariable(out ConditionVariable: Pointer); stdcall; external kernel32 name 'InitializeConditionVariable';
function SleepConditionVariableSRW(var ConditionalVariableSRW: Pointer; var SRWLock: Pointer; dwMilliseconds: DWORD; Flags: ULONG): BOOL; stdcall; external 'kernel32.dll' name 'SleepConditionVariableSRW';

procedure WakeConditionVariable(var ConditionVariable: Pointer); stdcall; external kernel32 name 'WakeConditionVariable';
procedure WakeAllConditionVariable(var ConditionVariable: Pointer); stdcall; external kernel32 name 'WakeAllConditionVariable';

procedure InitializeSRWLock(out P: Pointer); stdcall; external kernel32 name 'InitializeSRWLock';

procedure AcquireSRWLockShared(var P: Pointer); stdcall; external kernel32 name 'AcquireSRWLockShared';
procedure ReleaseSRWLockShared(var P: Pointer); stdcall; external kernel32 name 'ReleaseSRWLockShared';

procedure AcquireSRWLockExclusive(var P: Pointer); stdcall; external kernel32 name 'AcquireSRWLockExclusive';
procedure ReleaseSRWLockExclusive(var P: Pointer); stdcall; external kernel32 name 'ReleaseSRWLockExclusive';

function TryAcquireSRWLockExclusive(var P: Pointer): BOOL; stdcall; external kernel32 name 'TryAcquireSRWLockExclusive';
function TryAcquireSRWLockShared(var P: Pointer): BOOL; stdcall; external kernel32 name 'TryAcquireSRWLockShared';

{ TSRWLock }

procedure TSRWLock.AcquireShared;
begin
  //AcquireSRWLockShared(fHandle);
  CallAcquireSRWLockShared(fHandle);
end;

constructor TSRWLock.Create;
begin
  CallInitializeSRWLock := _InitializeSRWLock;

  CallAcquireSRWLockShared := _AcquireSRWLockShared;
  CallReleaseSRWLockShared := _ReleaseSRWLockShared;

  CallAcquireSRWLockExclusive := _AcquireSRWLockExclusive;
  CallReleaseSRWLockExclusive := _ReleaseSRWLockExclusive;

  CallTryAcquireSRWLockExclusive := _TryAcquireSRWLockExclusive;
  CallTryAcquireSRWLockShared := _TryAcquireSRWLockShared;

  InitializeSRWLock(fHandle);
  //CallInitializeSRWLock(fHandle);
end;

procedure TSRWLock.ReleaseShared;
begin
  //ReleaseSRWLockShared(fHandle);
  CallReleaseSRWLockShared(fHandle);
end;

function TSRWLock.TryAcquireExclusive: Boolean;
begin
  Result := CallTryAcquireSRWLockExclusive(fHandle);
end;

function TSRWLock.TryAcquireShared: Boolean;
begin
  Result := CallTryAcquireSRWLockShared(fHandle);
end;

procedure TSRWLock.AcquireExclusive;
begin
  //AcquireSRWLockExclusive(fHandle);
  CallAcquireSRWLockExclusive(fHandle);
end;

procedure TSRWLock.ReleaseExclusive;
begin
  //ReleaseSRWLockExclusive(fHandle);
  CallReleaseSRWLockExclusive(fHandle);
end;

{ TConditionalVariable }

constructor TConditionVariable.Create;
begin
  CallInitializeConditionVariable := _InitializeConditionVariable;
  CallSleepConditionVariableSRW := _SleepConditionVariableSRW;

  CallWakeConditionVariable := _WakeConditionVariable;
  CallWakeAllConditionVariable := _WakeAllConditionVariable;

  CallInitializeConditionVariable(fHandle);
end;

procedure TConditionVariable.Release;
begin
  CallWakeConditionVariable(fHandle);
end;

procedure TConditionVariable.ReleaseAll;
begin
  CallWakeAllConditionVariable(fHandle);
end;

function TConditionVariable.WaitFor(aSRWLock: TSRWLock; aTimeOut: Cardinal): TWaitResult;
begin
  if CallSleepConditionVariableSRW(fHandle, aSRWLock.fHandle, aTimeOut, 0) then
    Result := wrSignaled
  else
    case GetLastError of
      ERROR_TIMEOUT: Result := wrTimeout;
      WAIT_ABANDONED: Result := wrAbandoned;
    else
      Result := wrError;
    end;
end;

var
  kernalHndl: HModule;

initialization
  kernalHndl := GetModuleHandle(kernel32);

  @_InitializeConditionVariable := GetProcAddress(kernalHndl, 'InitializeConditionVariable');
  @_SleepConditionVariableSRW := GetProcAddress(kernalHndl, 'SleepConditionVariableSRW');

  @_WakeConditionVariable := GetProcAddress(kernalHndl, 'WakeConditionVariable');
  @_WakeAllConditionVariable := GetProcAddress(kernalHndl, 'WakeAllConditionVariable');

  @_InitializeSRWLock := GetProcAddress(kernalHndl, 'InitializeSRWLock');

  @_AcquireSRWLockShared := GetProcAddress(kernalHndl, 'AcquireSRWLockShared');
  @_ReleaseSRWLockShared := GetProcAddress(kernalHndl, 'ReleaseSRWLockShared');

  @_AcquireSRWLockExclusive := GetProcAddress(kernalHndl, 'AcquireSRWLockExclusive');
  @_ReleaseSRWLockExclusive := GetProcAddress(kernalHndl, 'ReleaseSRWLockExclusive');

  @_TryAcquireSRWLockExclusive := GetProcAddress(kernalHndl, 'TryAcquireSRWLockExclusive');
  @_TryAcquireSRWLockShared := GetProcAddress(kernalHndl, 'TryAcquireSRWLockShared');

finalization

end.

