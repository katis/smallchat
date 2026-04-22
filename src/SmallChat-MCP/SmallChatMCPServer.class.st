"
Runs a stdio MCP server loop inside the live Pharo image. Messages are
newline-delimited JSON objects (no embedded newlines). The reader runs on
a forked process so the UI event loop stays responsive.

Registered with SessionManager so the server starts automatically every
time the image is launched by Claude Code via ./bin/smallchat-mcp.

Stdout is reserved exclusively for MCP JSON-RPC. Any logging MUST go to
stderr or Transcript -- never System.out -- or framing will break.
"
Class {
	#name : 'SmallChatMCPServer',
	#superclass : 'Object',
	#instVars : [
		'readerProcess',
		'writeMutex',
		'protocol',
		'stdin',
		'stdout',
		'stderr',
		'running'
	],
	#classVars : [
		'Default'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing' }
SmallChatMCPServer class >> default [
	^ Default ifNil: [ Default := self new ]
]

{ #category : 'system startup' }
SmallChatMCPServer class >> logToFile: aString [
	"Append a line to <imageDir>/smallchat-mcp.log. Best-effort; swallows errors."
	[ | file |
	  file := Smalltalk vm imageFile parent / 'smallchat-mcp.log'.
	  file writeStreamDo: [ :s | s setToEnd; nextPutAll: aString; lf ] ]
		on: Error do: [ :e | ]
]

{ #category : 'accessing' }
SmallChatMCPServer class >> reset [
	Default ifNotNil: [ Default stop ].
	Default := nil
]

{ #category : 'system startup' }
SmallChatMCPServer class >> shutDown: isImageQuitting [
	"Stop on every shutdown event, not just quit. Save-then-continue also fires
	 shutDown: and we must clear the #running flag, otherwise the flag is
	 captured in the snapshot and the next image load thinks the reader is
	 already active and never re-opens stdin."
	Default ifNotNil: [ Default stop ]
]

{ #category : 'system startup' }
SmallChatMCPServer class >> startUp: isImageStarting [
	"Called by SessionManager on every image launch. The isImageStarting flag is
	 unreliable across launch modes -- under GUI `open -n -a` the VM fires startUp:
	 with false (Pharo treats our snapshot as 'continuing the session' because the
	 seed was created via `st --save` on the same session), so we can't gate on it.
	 #start is idempotent (bails if already running), so calling unconditionally
	 is safe. Errors are logged to a file because Transcript in GUI mode is
	 invisible to the smallchat-mcp wrapper shell."
	[ self default start ]
		on: Error
		do: [ :e |
			self logToFile: 'startUp error: ', e class name, ' - ', e messageText ]
]

{ #category : 'dispatch' }
SmallChatMCPServer >> handleLine: jsonLine [
	| message response |
	[
		message := STONJSON fromString: jsonLine.
	] on: Error do: [ :e |
		self logError: 'JSON parse error: ', e messageText, ' line: ', jsonLine.
		^ self ].

	response := protocol handleMessage: message.
	response ifNotNil: [ self writeMessage: response ]
]

{ #category : 'initialization' }
SmallChatMCPServer >> initialize [
	super initialize.
	writeMutex := Mutex new.
	protocol := SmallChatMCPProtocol default.
	running := false
]

{ #category : 'accessing' }
SmallChatMCPServer >> isRunning [
	^ running == true
]

{ #category : 'logging' }
SmallChatMCPServer >> logError: aString [
	self logToStderr: 'ERROR ', aString
]

{ #category : 'logging' }
SmallChatMCPServer >> logInfo: aString [
	self logToStderr: 'INFO ', aString
]

{ #category : 'logging' }
SmallChatMCPServer >> logToStderr: aString [
	"Never write to stdout -- it is reserved for MCP framing. Stderr is fine."
	stderr ifNil: [ ^ self ].
	[
		| line |
		line := '[smallchat] ', aString, (String with: Character lf).
		stderr isBinary
			ifTrue: [ stderr nextPutAll: line utf8Encoded ]
			ifFalse: [ stderr nextPutAll: line ].
		stderr flush
	] on: Error do: [ :e | "stderr may be unavailable; swallow" ]
]

{ #category : 'reading - stdio' }
SmallChatMCPServer >> mcpFifoNamed: baseName [
	"Return the FileReference to <imageDir>/<baseName> if it exists, else nil.
	 Pharo's VM exposes the image path via #imageFile (a FileReference), not
	 #imageDirectory."
	| ref |
	ref := Smalltalk vm imageFile parent / baseName.
	^ ref exists ifTrue: [ ref ] ifFalse: [ nil ]
]

{ #category : 'reading - stdio' }
SmallChatMCPServer >> muteTranscriptToStdout [
	"Pharo's headless Transcript mirrors to stdout, which corrupts our JSON-RPC
	 framing. Redirect Transcript to stderr (or null) so only our MCP responses
	 reach stdout."
	| redirected |
	redirected := (Smalltalk globals includesKey: #NonInteractiveTranscript)
		ifTrue: [
			[ (Smalltalk globals at: #NonInteractiveTranscript) stderr ]
				on: Error do: [ :e | nil ] ]
		ifFalse: [ nil ].
	redirected ifNotNil: [
		Smalltalk globals at: #Transcript put: redirected ]
]

{ #category : 'reading - stdio' }
SmallChatMCPServer >> readLine [
	"Read one line (LF-terminated) from stdin, returning its contents without the
	 trailing newline. Returns nil on EOF. Handles both byte- and character-oriented
	 streams by normalising each value to an Integer code point.

	 Must suspend on a VM-managed Semaphore between reads -- a raw #next performs a
	 blocking C read that stalls the whole VM, freezing the Morphic UI in pharo-ui
	 mode."
	| chars datum value |
	chars := (String new: 256) writeStream.
	[
		self waitForStdinData.
		datum := stdin next.
		datum ifNil: [
			^ chars position = 0 ifTrue: [ nil ] ifFalse: [ chars contents ] ].
		value := datum isInteger ifTrue: [ datum ] ifFalse: [ datum asInteger ].
		value = 10 ifTrue: [ ^ chars contents ].
		value = 13 ifFalse: [ chars nextPut: (Character value: value) ]
	] repeat
]

{ #category : 'reading - stdio' }
SmallChatMCPServer >> readLoop [
	| line |
	self class logToFile: 'readLoop: entered (reader process alive)'.
	[ running ] whileTrue: [
		line := self readLine.
		line ifNil: [
			self class logToFile: 'readLoop: EOF on stdin, stopping'.
			running := false. ^ self ].
		line isEmpty ifFalse: [ self handleLine: line ] ]
]

{ #category : 'reading - stdio' }
SmallChatMCPServer >> resolveStderr [
	(Smalltalk globals includesKey: #Stdio) ifTrue: [
		^ (Smalltalk globals at: #Stdio) stderr ].
	^ FileStream stderr
]

{ #category : 'reading - stdio' }
SmallChatMCPServer >> resolveStdin [
	"When the wrapper has placed a named pipe at <imageDir>/mcp.in, use that
	 instead of Stdio. Falls back to Stdio for the direct-exec headless path."
	| fifo |
	fifo := self mcpFifoNamed: 'mcp.in'.
	self class logToFile: 'resolveStdin: fifo=', fifo printString.
	fifo ifNotNil: [
		| s |
		s := fifo binaryReadStream.
		self class logToFile: 'resolveStdin: opened; class=', s class name.
		^ s ].
	(Smalltalk globals includesKey: #Stdio) ifTrue: [
		^ (Smalltalk globals at: #Stdio) stdin ].
	^ FileStream stdin
]

{ #category : 'reading - stdio' }
SmallChatMCPServer >> resolveStdout [
	| fifo |
	fifo := self mcpFifoNamed: 'mcp.out'.
	self class logToFile: 'resolveStdout: fifo=', fifo printString.
	fifo ifNotNil: [
		| s |
		s := fifo binaryWriteStream.
		self class logToFile: 'resolveStdout: opened; class=', s class name.
		^ s ].
	(Smalltalk globals includesKey: #Stdio) ifTrue: [
		^ (Smalltalk globals at: #Stdio) stdout ].
	^ FileStream stdout
]

{ #category : 'lifecycle' }
SmallChatMCPServer >> start [
	"Kill any stale reader from a saved snapshot before starting fresh -- the
	 #running flag and #readerProcess reference survive image save, but the
	 underlying OS-level stdio and Semaphore don't, so we must rebind both."
	readerProcess ifNotNil: [
		[ readerProcess terminate ] on: Error do: [ :e | ].
		readerProcess := nil ].
	running := false.
	stdin := self resolveStdin.
	self class logToFile: 'start: stdin assigned; class=', stdin class name.
	stdout := self resolveStdout.
	self class logToFile: 'start: stdout assigned; class=', stdout class name.
	stderr := self resolveStderr.
	self muteTranscriptToStdout.
	self class logToFile: 'start: about to fork reader'.
	running := true.
	self logInfo: 'SmallChatMCPServer starting...'.
	readerProcess := [
		[ self readLoop ]
			on: Error
			do: [ :e | self logError: 'read loop: ', e messageText, ' ', e class name ] ]
		forkAt: Processor lowIOPriority
		named: 'SmallChat MCP Reader'
]

{ #category : 'lifecycle' }
SmallChatMCPServer >> stop [
	running := false.
	readerProcess ifNotNil: [ :p | p terminate. readerProcess := nil ]
]

{ #category : 'reading - stdio' }
SmallChatMCPServer >> waitForStdinData [
	"Yield the VM to other processes until stdin has data or EOFs. Registers a
	 fresh Semaphore on each call so we don't depend on the shared one cached in
	 AbstractBinaryFileStream -- some Pharo builds only signal the first few
	 notifications on a reused semaphore for stdin, leaving the reader stuck.
	 Falls back silently on stream types without the primitive (legacy FileStream)."
	| handle sema semaIndex |
	(stdin respondsTo: #handle) ifFalse: [ ^ self ].
	handle := stdin handle.
	handle ifNil: [ ^ self ].
	sema := Semaphore new.
	semaIndex := Smalltalk registerExternalObject: sema.
	[
		[ File primitiveWaitForDataOn: handle signalling: semaIndex ]
			on: Error do: [ :e | self logError: 'primitiveWaitForData: ', e messageText. ^ self ].
		sema wait
	] ensure: [ Smalltalk unregisterExternalObject: sema ]
]

{ #category : 'writing' }
SmallChatMCPServer >> writeMessage: responseDictionary [
	"Serialize to JSON (no embedded newlines per MCP stdio spec) and write a
	 single line to stdout. Byte-oriented streams need us to encode the string
	 ourselves; character streams accept the String directly."
	| json bytes |
	json := STONJSON toString: responseDictionary.
	writeMutex critical: [
		stdout isBinary
			ifTrue: [
				bytes := json utf8Encoded.
				stdout nextPutAll: bytes; nextPut: 10 ]
			ifFalse: [
				stdout nextPutAll: json; nextPut: Character lf ].
		stdout flush ]
]
