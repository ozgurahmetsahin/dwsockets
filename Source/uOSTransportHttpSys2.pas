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
{    Copyright OddStorm Ltd.                                           }
{    Current maintainer: Chavdar Kopoev                                }
{                                                                      }
{**********************************************************************}
{
  Implementing Transport abstraction.
  Mainly dealing with sending/receiving entity body over http.sys request queue.

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL
}
unit uOSTransportHttpSys2;

interface

uses
  uOSTransport,
  dwsHTTPSysAPI,
  SRWLock,
  Generics.Collections,
  Winapi.Windows;

type
  TTransportOverlappedContextOp = (opConnect, opDisconnect, opRead, opWrite, opShutdown);

  TTansportOverlappedContext = class
    Op: TTransportOverlappedContextOp;
    Endpoint: TTransportEndpoint;
    Context: TTransportContext;
    Overlapped: Overlapped;
  end;

  TTansportOverlappedContextDict = TDictionary<POverlapped, TTansportOverlappedContext>;
  TTansportOverlappedContextHttpSys2 = class
  private
    fLock: TSRWLock;
    fDict: TTansportOverlappedContextDict;
  protected
  public
    constructor Create;
    destructor Destroy; override;

    function InsertContext(const aOp: TTransportOverlappedContextOp; const aEndpoint: TTransportEndpoint; const aContext: TTransportContext): POverlapped;
    procedure RemoveContext(const aOverlapped: POverlapped);
    function ExtractContext(const aOverlapped: POverlapped): TTansportOverlappedContext;
  end;

  TTrasportHttpSys2 = class (TTransport)
  private
    fWorkerThreads: array of THandle;
    fHttpSysReqQueue: THandle;
  protected
    fIOCompletion : THandle;
    fOverlappedContext: TTansportOverlappedContextHttpSys2;

    procedure InitializeThreads(const aWebSocketThreadsCount: Cardinal; const aConcurencyLevel: Cardinal);
    procedure FinalizeThreads;
  public
    constructor Create(const aHttpSysReqQueue: THandle; const aThreadWorkersCount: Integer; const aConcurencyLevel: Cardinal);
    destructor Destroy; override;

    procedure Shutdown(const aEndpoint: TTransportEndpoint); override;

    procedure Connect(const aEndpoint: TTransportEndpoint; const aContext: TTransportContext = nil); override;
    procedure Disconnect(const aEndpoint: TTransportEndpoint; const aContext: TTransportContext = nil); override;

    procedure Write(const aEndpoint: TTransportEndpoint; const aBuffer: Pointer; const aBufferSize: Cardinal;
      const aContext: TTransportContext = nil); override;
    procedure Read(const aEndpoint: TTransportEndpoint; const aBuffer: Pointer; const aBufferSize: Cardinal;
      const aContext: TTransportContext = nil); override;
  end;

  TTransportEndpointHttpSys2 = class (TTransportEndpoint)
  private
  protected
    fShuttedDown: Boolean;

    fHttpConnectionId: HTTP_CONNECTION_ID;
    fHttpReqId: HTTP_REQUEST_ID;

    fOverlappedRead: TOverlapped;
    fOverlappedWrite: TOverlapped;
    fPOverlappedRead: POverlapped;
    fPOverlappedWrite: POverlapped;

    fPendingAsyncCallbacks: Integer;

    function TriggerOnConnect(const aStatus: TTrasportStatus; const aContext: TTransportContext): Integer; inline;
    function TriggerOnDisconnect(const aStatus: TTrasportStatus; const aContext: TTransportContext): Integer; inline;
    function TriggerOnRead(const aStatus: TTrasportStatus; const aBytesProcessed: Cardinal; const aContext: TTransportContext): Integer; inline;
    function TriggerOnWrite(const aStatus: TTrasportStatus; const aBytesProcessed: Cardinal; const aContext: TTransportContext): Integer; inline;
  public
    constructor Create(const aId: TTransportEndpointId; const aTransport: TTransport;
      const aHttpConnectionId: HTTP_CONNECTION_ID; const aHttpReqId: HTTP_REQUEST_ID);
    destructor Destroy; override;

    procedure Connect(const aContext: TTransportContext = nil); override;
    procedure Disconnect(const aContext: TTransportContext = nil); override;

    //Make sure no following calls on transport endpoint methods will be done once called Shutdown
    procedure Shutdown; override;

    procedure Write(const aBuffer: Pointer; const aBufferSize: Cardinal; const aContext: TTransportContext = nil); override;
    procedure Read(const aBuffer: Pointer; const aBufferSize: Cardinal; const aContext: TTransportContext = nil); override;

    property ShuttedDown: Boolean read fShuttedDown;
    property PendingAsyncCallbacks: Integer read fPendingAsyncCallbacks;
  end;

implementation

uses
  System.SysUtils;

const
  // Posted to the completion port when shutting down
  C_THREAD_SHUTDOWN = Cardinal(-1);
  C_ENDPOINT_SHUTDOWN = Cardinal(-2);

function THttpApiWebSocketServerWorkerFunction(aParam: Pointer): Integer;
var
  transport: TTrasportHttpSys2 absolute aParam;
  bytesTransfered: Cardinal;
  endpoint: TTransportEndpointHttpSys2 absolute bytesTransfered;

  completionKey: ULONG_PTR;
  terminateEndpoint: TTransportEndpointHttpSys2 absolute completionKey;
  overlapped: POverlapped;

  overlappedContext: TTansportOverlappedContext;
  transportStatus: TTrasportStatus;
  overlappedEndpoint: TTransportEndpointHttpSys2;

  pac: Integer;
begin
  while True do
  begin
    try
      transportStatus := tsDone;

      if not GetQueuedCompletionStatus(transport.fIOCompletion, bytesTransfered, completionKey, overlapped, INFINITE) then
        transportStatus := tsDisconnected;

      if NativeUInt(overlapped) = C_THREAD_SHUTDOWN then
        Break; // exit thread

      overlappedContext := transport.fOverlappedContext.ExtractContext(overlapped);
      try
        if (transportStatus = tsDone) and (overlapped.Internal <> S_OK) then
          transportStatus := tsError;

        pac := 1;
        overlappedEndpoint := TTransportEndpointHttpSys2(overlappedContext.Endpoint);
        try
          case overlappedContext.Op of
            opConnect:
              pac := overlappedEndpoint.TriggerOnConnect(transportStatus, overlappedContext.Context);
            opDisconnect:
              pac := overlappedEndpoint.TriggerOnDisconnect(transportStatus, overlappedContext.Context);
            opRead:
              pac := overlappedEndpoint.TriggerOnRead(transportStatus, bytesTransfered, overlappedContext.Context);
            opWrite:
              pac := overlappedEndpoint.TriggerOnWrite(transportStatus, bytesTransfered, overlappedContext.Context);
            opShutdown:
              pac := InterlockedDecrement(overlappedEndpoint.fPendingAsyncCallbacks);
          end;
        finally
          if overlappedEndpoint.ShuttedDown and (pac = 0) then
            overlappedEndpoint.Free;
        end;
      finally
        overlappedContext.Free;
      end;
    except
      on Exception do
        ; // we should handle all exceptions in this loop
    end;
  end;

  Result := 0;
end;

{ TTrasportHttpSys2 }

procedure TTrasportHttpSys2.Connect(const aEndpoint: TTransportEndpoint; const aContext: TTransportContext);
begin
  PostQueuedCompletionStatus(fIOCompletion, 0, 0, fOverlappedContext.InsertContext(opConnect, aEndpoint, aContext));
end;

constructor TTrasportHttpSys2.Create(const aHttpSysReqQueue: THandle; const aThreadWorkersCount: Integer;
  const aConcurencyLevel: Cardinal);
begin
  inherited Create;

  fHttpSysReqQueue := aHttpSysReqQueue;

  fOverlappedContext := TTansportOverlappedContextHttpSys2.Create;

  InitializeThreads(aThreadWorkersCount, aConcurencyLevel);
end;

destructor TTrasportHttpSys2.Destroy;
begin
  FinalizeThreads;
  fOverlappedContext.Free;

  inherited;
end;

procedure TTrasportHttpSys2.Disconnect(const aEndpoint: TTransportEndpoint; const aContext: TTransportContext);
var
  endpoint: TTransportEndpointHttpSys2 absolute aEndpoint;
  overlapped: POverlapped;

  httpSendEntity: HTTP_DATA_CHUNK_INMEMORY;
  httpBytesSent: Cardinal;

  hr: HRESULT;
begin
  httpSendEntity.DataChunkType := hctFromMemory;
  httpSendEntity.pBuffer := nil;
  httpSendEntity.BufferLength := 0;

  overlapped := fOverlappedContext.InsertContext(opDisconnect, aEndpoint, aContext);

  hr := HttpAPI.SendResponseEntityBody(fHttpSysReqQueue, endpoint.fHttpReqId,
          HTTP_SEND_RESPONSE_FLAG_DISCONNECT,
          1, @httpSendEntity, httpBytesSent, nil, 0, overlapped);

  case hr of
    ERROR_HANDLE_EOF:
      begin
        fOverlappedContext.RemoveContext(overlapped);
        endpoint.TriggerOnDisconnect(tsError, aContext);
      end;
    ERROR_IO_PENDING: ;
    NO_ERROR: ;
  else
    begin
      fOverlappedContext.RemoveContext(overlapped);
      endpoint.TriggerOnDisconnect(tsError, aContext);
    end;
  end;
end;

procedure TTrasportHttpSys2.FinalizeThreads;
var
  i: Integer;
begin
  if fIOCompletion <> 0 then
  begin
    // Tell the threads we're shutting down
    for i := 0 to High(fWorkerThreads) do
      PostQueuedCompletionStatus(fIOCompletion, 0, 0, POverLapped(C_THREAD_SHUTDOWN));

    // Wait for threads to finish, with 10 seconds TimeOut
    WaitForMultipleObjects(Length(fWorkerThreads), Pointer(fWorkerThreads), True, 10000);

    // Close the request queue handle
    CloseHandle(fIOCompletion);
    fIOCompletion := 0;

    // Close the thread handles
    for i := 0 to high(fWorkerThreads) do
      CloseHandle(fWorkerThreads[I]);
  end;

  SetLength(fWorkerThreads, 0);
end;

procedure TTrasportHttpSys2.InitializeThreads(const aWebSocketThreadsCount: Cardinal; const aConcurencyLevel: Cardinal);
var
  i: Integer;
  lThreadID: TThreadID;
begin
  fIOCompletion := CreateIoCompletionPort(fHttpSysReqQueue, 0, NativeUInt(fHttpSysReqQueue), aConcurencyLevel);

  if fIOCompletion = INVALID_HANDLE_VALUE then
  begin
    fIOCompletion := 0;
    Exit;
  end;

  // Now create the worker threads
  Setlength(fWorkerThreads, aWebSocketThreadsCount);
  for i := 0 to high(fWorkerThreads) do
    fWorkerThreads[i] := BeginThread(nil, 0, THttpApiWebSocketServerWorkerFunction, Self, 0, lThreadID);
end;

procedure TTrasportHttpSys2.Read(const aEndpoint: TTransportEndpoint; const aBuffer: Pointer;
  const aBufferSize: Cardinal; const aContext: TTransportContext);
var
  endpoint: TTransportEndpointHttpSys2 absolute aEndpoint;
  overlapped: POverlapped;
  bytesRead: Cardinal;
  hr: HRESULT;
begin
  bytesRead := 0;

  overlapped := fOverlappedContext.InsertContext(opRead, aEndpoint, aContext);

  hr := HttpAPI.ReceiveRequestEntityBody(fHttpSysReqQueue, endpoint.fHttpReqId, 0,
          aBuffer, aBufferSize, bytesRead, overlapped);

  case hr of
    ERROR_HANDLE_EOF:
      begin
        fOverlappedContext.RemoveContext(overlapped);
        endpoint.TriggerOnRead(tsEOF, bytesRead, aContext);
      end;
    ERROR_IO_PENDING: ;
    NO_ERROR: ;
  else
    begin
      fOverlappedContext.RemoveContext(overlapped);
      endpoint.TriggerOnRead(tsError, bytesRead, aContext);
    end;
  end;
end;

procedure TTrasportHttpSys2.Shutdown(const aEndpoint: TTransportEndpoint);
begin
  PostQueuedCompletionStatus(fIOCompletion, 0, 0, fOverlappedContext.InsertContext(opShutdown, aEndpoint, nil));
end;

procedure TTrasportHttpSys2.Write(const aEndpoint: TTransportEndpoint; const aBuffer: Pointer;
  const aBufferSize: Cardinal; const aContext: TTransportContext);
var
  endpoint: TTransportEndpointHttpSys2 absolute aEndpoint;
  overlapped: POverlapped;

  httpSendEntity: HTTP_DATA_CHUNK_INMEMORY;
  bytesWrite: Cardinal;

  hr: HRESULT;
begin
  bytesWrite := 0;

  httpSendEntity.DataChunkType := hctFromMemory;
  httpSendEntity.pBuffer := aBuffer;
  httpSendEntity.BufferLength := aBufferSize;

  overlapped := fOverlappedContext.InsertContext(opWrite, aEndpoint, aContext);

  hr := HttpAPI.SendResponseEntityBody(fHttpSysReqQueue, endpoint.fHttpReqId,
          HTTP_SEND_RESPONSE_FLAG_BUFFER_DATA or HTTP_SEND_RESPONSE_FLAG_MORE_DATA,
          1, @httpSendEntity, bytesWrite, nil, 0, overlapped);

  case hr of
    ERROR_HANDLE_EOF:
      begin
        fOverlappedContext.RemoveContext(overlapped);
        endpoint.TriggerOnWrite(tsEOF, bytesWrite, aContext);
      end;
    ERROR_IO_PENDING: ;
    NO_ERROR: ;
  else
    begin
      fOverlappedContext.RemoveContext(overlapped);
      endpoint.TriggerOnWrite(tsError, 0, aContext);
    end;
  end;
end;

{ TTransportEndpointHttpSys2 }

procedure TTransportEndpointHttpSys2.Connect(const aContext: TTransportContext);
begin
  InterlockedIncrement(fPendingAsyncCallbacks);
  fTransport.Connect(Self, aContext);
end;

constructor TTransportEndpointHttpSys2.Create(const aId: TTransportEndpointId; const aTransport: TTransport;
  const aHttpConnectionId: HTTP_CONNECTION_ID; const aHttpReqId: HTTP_REQUEST_ID);
begin
  inherited Create(aId, aTransport);

  fShuttedDown := False;

  fHttpConnectionId := aHttpConnectionId;
  fHttpReqId := aHttpReqId;

  fPOverlappedRead := @fOverlappedRead;
  fPOverlappedWrite := @fOverlappedWrite
end;

destructor TTransportEndpointHttpSys2.Destroy;
begin
  inherited;
end;

procedure TTransportEndpointHttpSys2.Disconnect(const aContext: TTransportContext);
begin
  InterlockedIncrement(fPendingAsyncCallbacks);
  fTransport.Disconnect(Self, aContext);
end;

procedure TTransportEndpointHttpSys2.Read(const aBuffer: Pointer; const aBufferSize: Cardinal;
  const aContext: TTransportContext);
begin
  InterlockedIncrement(fPendingAsyncCallbacks);
  fTransport.Read(Self, aBuffer, aBufferSize, aContext);
end;

procedure TTransportEndpointHttpSys2.Shutdown;
begin
  fOnConnect := nil;
  fOnDisconnect := nil;
  fOnWrite := nil;
  fOnRead := nil;

  fShuttedDown := True;

  InterlockedIncrement(fPendingAsyncCallbacks);
  fTransport.Shutdown(Self);
end;

function TTransportEndpointHttpSys2.TriggerOnConnect(const aStatus: TTrasportStatus;
  const aContext: TTransportContext): Integer;
begin
  if Assigned(fOnConnect) then
    fOnConnect(aStatus, aContext);
  Result := InterlockedDecrement(fPendingAsyncCallbacks);
end;

function TTransportEndpointHttpSys2.TriggerOnDisconnect(const aStatus: TTrasportStatus;
  const aContext: TTransportContext): Integer;
begin
  if Assigned(fOnDisconnect) then
    fOnDisconnect(aStatus, aContext);
  Result := InterlockedDecrement(fPendingAsyncCallbacks);
end;

function TTransportEndpointHttpSys2.TriggerOnRead(const aStatus: TTrasportStatus; const aBytesProcessed: Cardinal;
  const aContext: TTransportContext): Integer;
begin
  if Assigned(fOnRead) then
    fOnRead(aStatus, aBytesProcessed, aContext);
  Result := InterlockedDecrement(fPendingAsyncCallbacks);
end;

function TTransportEndpointHttpSys2.TriggerOnWrite(const aStatus: TTrasportStatus; const aBytesProcessed: Cardinal;
  const aContext: TTransportContext): Integer;
begin
  if Assigned(fOnWrite) then
    fOnWrite(aStatus, aBytesProcessed, aContext);
  Result := InterlockedDecrement(fPendingAsyncCallbacks);
end;

procedure TTransportEndpointHttpSys2.Write(const aBuffer: Pointer; const aBufferSize: Cardinal;
  const aContext: TTransportContext);
begin
  InterlockedIncrement(fPendingAsyncCallbacks);
  fTransport.Write(Self, aBuffer, aBufferSize, aContext);
end;

{ TTansportOverlappedContextHttpSys2 }

constructor TTansportOverlappedContextHttpSys2.Create;
begin
  fLock := TSRWLock.Create;
  fDict := TTansportOverlappedContextDict.Create;
end;

destructor TTansportOverlappedContextHttpSys2.Destroy;
begin
  fLock.Free;
  fDict.Free;

  inherited;
end;

function TTansportOverlappedContextHttpSys2.ExtractContext(const aOverlapped: POverlapped): TTansportOverlappedContext;
begin
  fLock.AcquireExclusive;
  try
    Result := fDict.ExtractPair(aOverlapped).Value;
  finally
    fLock.ReleaseExclusive;
  end;
end;

function TTansportOverlappedContextHttpSys2.InsertContext(const aOp: TTransportOverlappedContextOp;
  const aEndpoint: TTransportEndpoint; const aContext: TTransportContext): POverlapped;
var
  overlappedContext: TTansportOverlappedContext;
begin
  overlappedContext := TTansportOverlappedContext.Create;

  overlappedContext.Op := aOp;
  overlappedContext.Endpoint := aEndpoint;
  overlappedContext.Context := aContext;

  Result := @overlappedContext.Overlapped;

  fLock.AcquireExclusive;
  try
    fDict.Add(Result, overlappedContext);
  finally
    fLock.ReleaseExclusive;
  end;
end;

procedure TTansportOverlappedContextHttpSys2.RemoveContext(const aOverlapped: POverlapped);
begin
  fLock.AcquireExclusive;
  try
    fDict.ExtractPair(aOverlapped).Value.Free;
  finally
    fLock.ReleaseExclusive;
  end;
end;

end.
