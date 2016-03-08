
---

Websockets support for [DelphiWebScript http.sys 2 web server](http://code.google.com/p/dwscript/wiki/WebServer)

---


### Introduction ###
DelphiWebSockets project is an implementation of [DelphiWebScript WebServer](http://code.google.com/p/dwscript/wiki/WebServer), which on behalf implements [mORMot Framework](http://blog.synopse.info/) generic server logic.

WebSocket Server uses abstract transport and is not dependent on the http.sys server implementation.
Can be used on the top of other transport (ex. custom tcp connection, pipes).

**Windows 8** or **Windows Server 2012** is required, as DWSockets use
[Windows WebSocket Protocol Component API](http://msdn.microsoft.com/en-us/library/windows/desktop/hh437448%28v=vs.85%29.aspx).

### To Do ###

  * WebSocket client, based on WinHttpWebSocket**`*`** family functions
  * Test client/server scenarios and usage examples
  * Expose web socket server functionality to DelphiWebScript
  * Interface current abstraction usage
  * Handle large message buffer

### Notes ###
  * Current sources are in very early preview, not tested in production!
  * Lead platform currently is Delphi XE5, no backward compatibility is maintained.

### Change Log ###
2013-12-11
  * Synced with latest DWScript
  * Minor changes