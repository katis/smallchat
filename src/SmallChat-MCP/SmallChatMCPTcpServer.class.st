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
SmallChatMCPTcpServer >> currentState [
	"Fresh snapshot of running + client count. Safe to call from any process."
	^ SmallChatMCPStateChanged new
		running: (running == true);
		clientCount: self activeClientCount;
		yourself
]

{ #category : 'listening' }
SmallChatMCPTcpServer >> handleConnection: clientSocket [
	"Run newline-delimited JSON-RPC on the given socket until the client
	 disconnects. Each line is one MCP message; response is written back
	 with a trailing LF. Per MCP spec, messages contain no embedded newlines."
	| stream |
	stream := SocketStream on: clientSocket.
	stream timeout: 3600.
	[
		[ stream atEnd ] whileFalse: [ self serveOneMessage: stream ]
	] on: Error do: [ :e |
		SmallChatMCPServer logToFile: 'tcp handleConnection: ', e messageText ].
	[ stream close ] on: Error do: [ :e | ].
	[ clientSocket destroy ] on: Error do: [ :e | ].
	SmallChatMCPServer logToFile: 'tcp: client closed'
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
SmallChatMCPTcpServer >> registerClient: aClient [
	clientsMutex critical: [ activeClients add: aClient ].
	self announceState
]

{ #category : 'private' }
SmallChatMCPTcpServer >> removePortFile [
	[ | file |
	  file := Smalltalk vm imageFile parent / 'mcp.port'.
	  file exists ifTrue: [ file delete ] ]
		on: Error do: [ :e | ]
]

{ #category : 'listening' }
SmallChatMCPTcpServer >> serveOneMessage: stream [
	| line message response |
	line := self readLineFrom: stream.
	line ifNil: [ ^ self ].
	line isEmpty ifTrue: [ ^ self ].
	message := [ STONJSON fromString: line ]
		on: Error
		do: [ :e |
			SmallChatMCPServer logToFile: 'tcp parse error: ', e messageText.
			^ self ].
	response := protocol handleMessage: message.
	response ifNotNil: [
		| json |
		json := STONJSON toString: response.
		"Encode to UTF-8 bytes (wrapped back into a ByteString so the
		 text-mode SocketStream writes them 1:1). If we write the raw
		 WideString, SocketStream emits each code point as 4 raw bytes,
		 which shows up as UTF-32-looking gibberish on the wire and
		 silently breaks the client's newline framing from that message
		 onwards."
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

{ #category : 'private' }
SmallChatMCPTcpServer >> unregisterClient: aClient [
	clientsMutex critical: [ activeClients remove: aClient ifAbsent: [ nil ] ].
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
