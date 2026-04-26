"
Listens for MCP JSON-RPC connections on 127.0.0.1 and runs each through
SmallChatMCPProtocol. Used by the GUI-mode smallchat-mcp launcher: the
shell launches Pharo.app via `open -n -a` (which properly registers the
window with LaunchServices) and then bridges Claude's stdio to this TCP
port.

The port is chosen by the OS (bind to 0) and written to
<imageDir>/mcp.port so the smallchat-mcp shell can find it. Only bound to
127.0.0.1 — other machines can't reach it.
"
Class {
	#name : 'SmallChatMCPTcpServer',
	#superclass : 'Object',
	#instVars : [
		'listener',
		'acceptProcess',
		'protocol',
		'running',
		'port',
		'activeClients',
		'clientsMutex',
		'announcer'
	],
	#classVars : [
		'Default'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing' }
SmallChatMCPTcpServer class >> default [
	^ Default ifNil: [ Default := self new ]
]

{ #category : 'accessing' }
SmallChatMCPTcpServer class >> reset [
	Default ifNotNil: [ Default stop ].
	Default := nil
]

{ #category : 'system startup' }
SmallChatMCPTcpServer class >> shutDown: isImageQuitting [
	"Stop on save-and-continue and quit alike. Without this the #running
	 flag survives into the snapshot and the next launch skips #start."
	Default ifNotNil: [ Default stop ]
]

{ #category : 'system startup' }
SmallChatMCPTcpServer class >> startUp: isImageStarting [
	"Start on every image launch. Errors go to smallchat-mcp.log because
	 stderr in GUI mode is detached by `open -n -a`."
	[ self default start ]
		on: Error
		do: [ :e |
			SmallChatMCPServer logToFile: 'tcp startUp error: ', e class name, ' - ', e messageText ]
]

{ #category : 'listening' }
SmallChatMCPTcpServer >> acceptLoop [
	"Accept client connections one at a time. Each client gets its own
	 forked process running the MCP protocol loop, so concurrent Claude Code
	 sessions don't block each other."
	SmallChatMCPServer logToFile: 'tcp: acceptLoop entered'.
	[ running ] whileTrue: [
		| client |
		client := [ listener waitForAcceptFor: 1 ]
			on: Error
			do: [ :e | nil ].
		client ifNotNil: [
			SmallChatMCPServer logToFile: 'tcp: accepted connection'.
			[ self handleConnection: client ]
				forkAt: Processor lowIOPriority
				named: 'SmallChat MCP TCP Client' ] ]
]

{ #category : 'accessing' }
SmallChatMCPTcpServer >> activeClientCount [
	^ clientsMutex critical: [ activeClients size ]
]

{ #category : 'private' }
SmallChatMCPTcpServer >> announceState [
	self announcer announce: self currentState
]

{ #category : 'accessing' }
SmallChatMCPTcpServer >> announcer [
	"Broadcasts SmallChatMCPStateChanged when the listener starts/stops or
	 when a client connects/disconnects. UI subscribes here."
	^ announcer ifNil: [ announcer := Announcer new ]
]

{ #category : 'accessing' }
SmallChatMCPTcpServer >> connections [
    "Snapshot of the active connection set. Mutating the returned
     collection does not affect the server. Live updates flow through
     the announcer (Added / Removed / ToolCallRecorded)."
    ^ clientsMutex critical: [ activeClients copy ]
]

{ #category : 'accessing' }
SmallChatMCPTcpServer >> currentState [
	"Fresh snapshot of running + client count. Safe to call from any process."
	^ SmallChatMCPStateChanged new
		running: (running == true);
		clientCount: self activeClientCount;
		yourself
]

{ #category : 'listening' }
SmallChatMCPTcpServer >> handleConnection: clientSocket [
    "Wrap the raw socket in a SmallChatMCPConnection, register it, run the
     JSON-RPC loop, then unregister on any exit path (normal EOF, internal
     error, or an exception that escapes the session body)."
    | conn |
    conn := SmallChatMCPConnection on: clientSocket.
    self registerConnection: conn.
    [ self runClientSessionOn: conn ]
        ensure: [
            self unregisterConnection: conn.
            SmallChatMCPServer logToFile: 'tcp: client closed' ]
]

{ #category : 'initialization' }
SmallChatMCPTcpServer >> initialize [
	super initialize.
	protocol := SmallChatMCPProtocol default.
	running := false.
	activeClients := OrderedCollection new.
	clientsMutex := Mutex new
]

{ #category : 'accessing' }
SmallChatMCPTcpServer >> port [
	^ port
]

{ #category : 'private' }
SmallChatMCPTcpServer >> readLineFrom: stream [
	"Read up to the next LF. Returns nil on EOF, the line contents otherwise
	 (without the trailing newline). SocketStream's #upTo: stops at LF but
	 doesn't distinguish empty-line from EOF, so we check #atEnd first."
	| bytes |
	stream atEnd ifTrue: [ ^ nil ].
	bytes := stream upTo: Character lf.
	^ bytes asString trimRight
]

{ #category : 'private' }
SmallChatMCPTcpServer >> recordIfToolsCall: aMessageDict response: aResponseDict durationMs: aMs onConnection: aConnection [
    "If aMessageDict is a tools/call request, build a SmallChatMCPCallRecord
     against the rendered response and append it to the connection's call
     log; broadcast SmallChatMCPToolCallRecorded so the console window picks
     it up. Other JSON-RPC methods (initialize, tools/list, ping,
     notifications) are silently skipped."
    | record |
    aResponseDict ifNil: [ ^ self ].
    record := SmallChatMCPCallRecord
        from: aMessageDict
        response: aResponseDict
        durationMs: aMs.
    record ifNil: [ ^ self ].
    aConnection calls add: record.
    self announcer announce: (SmallChatMCPToolCallRecorded new
        connection: aConnection;
        record: record;
        yourself)
]

{ #category : 'connections' }
SmallChatMCPTcpServer >> registerConnection: aConnection [
    "Add aConnection to the active set, announce a fresh
     SmallChatMCPConnectionAdded for tab-builders, and re-emit
     SmallChatMCPStateChanged for the running+count subscribers."
    clientsMutex critical: [ activeClients add: aConnection ].
    self announcer announce: (SmallChatMCPConnectionAdded new
        connection: aConnection;
        yourself).
    self announceState
]

{ #category : 'private' }
SmallChatMCPTcpServer >> removePortFile [
	[ | file |
	  file := Smalltalk vm imageFile parent / 'mcp.port'.
	  file exists ifTrue: [ file delete ] ]
		on: Error do: [ :e | ]
]

{ #category : 'private' }
SmallChatMCPTcpServer >> runClientSessionOn: aConnection [
    "Serve JSON-RPC over aConnection's socket until EOF. Extracted from
     #handleConnection: so tests can substitute this step to simulate
     failure without a real socket."
    | stream socket |
    socket := aConnection socket.
    stream := SocketStream on: socket.
    stream timeout: 3600.
    [
        [ stream atEnd ] whileFalse: [ self serveOneMessage: stream on: aConnection ]
    ] on: Error do: [ :e |
        SmallChatMCPServer logToFile: 'tcp handleConnection: ', e messageText ].
    [ stream close ] on: Error do: [ :e | ].
    [ socket destroy ] on: Error do: [ :e | ]
]

{ #category : 'listening' }
SmallChatMCPTcpServer >> serveOneMessage: stream on: aConnection [
    "Read one JSON-RPC line, dispatch via the protocol, record the call
     onto aConnection if it was a tools/call, and write the response."
    | line message response startMs durationMs |
    line := self readLineFrom: stream.
    line ifNil: [ ^ self ].
    line isEmpty ifTrue: [ ^ self ].
    message := [ STONJSON fromString: line ]
        on: Error
        do: [ :e |
            SmallChatMCPServer logToFile: 'tcp parse error: ', e messageText.
            ^ self ].
    startMs := Time millisecondClockValue.
    response := protocol handleMessage: message.
    durationMs := Time millisecondClockValue - startMs.
    self recordIfToolsCall: message response: response durationMs: durationMs onConnection: aConnection.
    response ifNotNil: [
        | json |
        json := STONJSON toString: response.
        stream
            nextPutAll: json utf8Encoded asString;
            nextPut: Character lf;
            flush ]
]

{ #category : 'lifecycle' }
SmallChatMCPTcpServer >> start [
	"Bind 127.0.0.1:0 (OS picks a free port), write the port to disk for the
	 smallchat-mcp shell to read, and fork the accept loop. Idempotent: bails
	 silently if #running survived a save."
	running ifTrue: [ ^ self ].
	listener := Socket newTCP.
	listener listenOn: 0 backlogSize: 8 interface: #[127 0 0 1].
	port := listener localPort.
	self writePortFile.
	SmallChatMCPServer logToFile: 'tcp: listening on 127.0.0.1:', port printString.
	self updateRunning: true.
	acceptProcess := [
		[ self acceptLoop ]
			on: Error
			do: [ :e | SmallChatMCPServer logToFile: 'tcp acceptLoop: ', e messageText ] ]
		forkAt: Processor lowIOPriority
		named: 'SmallChat MCP TCP Listener'
]

{ #category : 'lifecycle' }
SmallChatMCPTcpServer >> stop [
	self updateRunning: false.
	acceptProcess ifNotNil: [ :p |
		[ p terminate ] on: Error do: [ :e | ].
		acceptProcess := nil ].
	listener ifNotNil: [
		[ listener destroy ] on: Error do: [ :e | ].
		listener := nil ].
	self removePortFile
]

{ #category : 'connections' }
SmallChatMCPTcpServer >> unregisterConnection: aConnection [
    "Mark aConnection closed, drop it from the active set, announce
     SmallChatMCPConnectionRemoved (with isClosed already true on the
     payload), then re-emit SmallChatMCPStateChanged."
    aConnection markClosed.
    clientsMutex critical: [ activeClients remove: aConnection ifAbsent: [ nil ] ].
    self announcer announce: (SmallChatMCPConnectionRemoved new
        connection: aConnection;
        yourself).
    self announceState
]

{ #category : 'private' }
SmallChatMCPTcpServer >> updateRunning: aBoolean [
	"Flip the running flag and fire a state-change announcement. Used by
	 #start and #stop so the GUI (or any other subscriber) sees transitions."
	running := aBoolean.
	self announceState
]

{ #category : 'private' }
SmallChatMCPTcpServer >> writePortFile [
	| file |
	file := Smalltalk vm imageFile parent / 'mcp.port'.
	[ file writeStreamDo: [ :s | s nextPutAll: port printString ] ]
		on: Error do: [ :e | ]
]
