Class {
	#name : 'SmallChatLSPStdioTransport',
	#superclass : 'Object',
	#instVars : [
		'output',
		'input',
		'waitStrategy',
		'process',
		'isInputAliveBlock',
		'stderrReaderProcess',
		'stderrRunning'
	],
	#classVars : [
		'PnpmTsgoProbeBlock'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'instance creation' }
SmallChatLSPStdioTransport class >> defaultTsgoPathFor: aWorkspaceRoot [
	"Expected tsgo binary location when @typescript/native-preview is installed in
	 aWorkspaceRoot's node_modules. M1 hard-codes darwin-arm64 per S3 dylib
	 vendoring; platform detection can follow when another arch needs support."
	^ aWorkspaceRoot asFileReference
		/ 'node_modules' / '@typescript' / 'native-preview-darwin-arm64'
		/ 'lib' / 'tsgo'
]

{ #category : 'logging' }
SmallChatLSPStdioTransport class >> logToFile: aString [
	"Append a line to <imageDir>/smallchat-lsp.log. Best-effort; swallows errors."
	[ | file |
		file := Smalltalk vm imageFile parent / 'smallchat-lsp.log'.
		file writeStreamDo: [ :s | s setToEnd; nextPutAll: aString; lf ] ]
		on: Error do: [ :e | ]
]

{ #category : 'tsgo resolution' }
SmallChatLSPStdioTransport class >> pnpmCanRunTsgoIn: aWorkspaceRoot [
	"Probe: returns true when `pnpm exec --silent tsgo --version` exits 0
	 from aWorkspaceRoot -- support hoisted installs where node_modules/.bin
	 does not list tsgo. Honours pnpmTsgoProbeBlock: as a test seam.
	 Live path bounds the probe to ~5s so a hung pnpm cannot stall attach."
	| procClass proc deadline |
	PnpmTsgoProbeBlock ifNotNil: [ ^ PnpmTsgoProbeBlock value: aWorkspaceRoot ].
	procClass := Smalltalk globals at: #OSSUnixSubprocess ifAbsent: [ ^ false ].
	proc := procClass new
		command: 'pnpm';
		arguments: #('exec' '--silent' 'tsgo' '--version');
		workingDirectory: aWorkspaceRoot pathString;
		redirectStdin;
		redirectStdout;
		redirectStderr;
		yourself.
	[ proc run ] on: Error do: [ :_ | ^ false ].
	deadline := Time millisecondClockValue + 5000.
	[ proc isRunning ] whileTrue: [
		Time millisecondClockValue > deadline ifTrue: [
			[ proc terminate ] on: Error do: [ :_ | ].
			^ false ].
		(Delay forMilliseconds: 25) wait ].
	^ proc exitStatusInterpreter isSuccess
]

{ #category : 'tsgo resolution' }
SmallChatLSPStdioTransport class >> pnpmTsgoProbeBlock: aBlock [
	"Test seam: replace the pnpm-exec probe used by resolveTsgoCommandIn:.
	 Block receives the workspace FileReference and answers a Boolean (true ->
	 pnpm exec --silent tsgo --version exits 0). resetPnpmTsgoProbeBlock
	 restores the live shell-out."
	PnpmTsgoProbeBlock := aBlock
]

{ #category : 'tsgo resolution' }
SmallChatLSPStdioTransport class >> resetPnpmTsgoProbeBlock [
	"Drop the test-installed probe so resolveTsgoCommandIn: shells out for real."
	PnpmTsgoProbeBlock := nil
]

{ #category : 'tsgo resolution' }
SmallChatLSPStdioTransport class >> resolveTsgoCommandIn: aWorkspaceRoot [
	"Resolve the spawn command for tsgo --lsp --stdio against aWorkspaceRoot.
	 Returns an Array whose first element is the executable and the rest are
	 base arguments (--lsp / --stdio are appended by launchWith:at:).

	 Rule:
	   1. <root>/node_modules/.bin/tsgo if it exists -> { binPath }.
	   2. Else if pnpm exec --silent tsgo --version exits 0 from aWorkspaceRoot
	      -> #('pnpm' 'exec' '--silent' 'tsgo') for hoisted installs.
	   3. Else raise an Error naming aWorkspaceRoot so the agent knows where
	      to install tsgo.
	 No global PATH lookup -- the workspace owns its tsgo binary."
	| binPath |
	binPath := aWorkspaceRoot asFileReference / 'node_modules' / '.bin' / 'tsgo'.
	binPath exists ifTrue: [ ^ Array with: binPath fullName ].
	(self pnpmCanRunTsgoIn: aWorkspaceRoot) ifTrue: [
		^ #('pnpm' 'exec' '--silent' 'tsgo') ].
	^ self error: 'tsgo not installed in ' , aWorkspaceRoot pathString , '; install it as a dev dependency in the project'
]

{ #category : 'initialization' }
SmallChatLSPStdioTransport >> initialize [
	super initialize.
	waitStrategy := [ (Delay forMilliseconds: 10) wait ]
]

{ #category : 'accessing' }
SmallChatLSPStdioTransport >> input: aStream [
	input := aStream.
	^ self
]

{ #category : 'reading' }
SmallChatLSPStdioTransport >> isInputAlive [
	"True while input can still produce bytes. Overridable via isInputAliveBlock:
	 defaults to #atEnd negation (correct for in-memory ReadStreams used in tests).
	 The live tsgo path sets this to check the subprocess isRunning, because
	 OSSPipe#atEnd returns true whenever the buffer is currently empty -- which
	 confuses it with EOF."
	isInputAliveBlock ifNotNil: [ ^ isInputAliveBlock value ].
	^ input atEnd not
]

{ #category : 'accessing' }
SmallChatLSPStdioTransport >> isInputAliveBlock: aBlock [
	isInputAliveBlock := aBlock.
	^ self
]

{ #category : 'lifecycle' }
SmallChatLSPStdioTransport >> launchTsgoAt: aWorkspaceRoot [
	"Spawn tsgo --lsp --stdio under aWorkspaceRoot, wire stdin/stdout for the
	 framing layer, and fork a stderr reader that forwards each line to the
	 shared log file. Raises on missing binary or missing OSSubprocess."
	| path procClass proc |
	procClass := Smalltalk globals at: #OSSUnixSubprocess ifAbsent: [
		^ self error: 'OSSubprocess is not loaded; launch the dev image' ].
	path := self class defaultTsgoPathFor: aWorkspaceRoot.
	path exists ifFalse: [
		^ self error: 'tsgo binary missing at ' , path pathString ].
	proc := procClass new
		command: path pathString;
		arguments: #('--lsp' '--stdio');
		workingDirectory: aWorkspaceRoot pathString;
		redirectStdin;
		redirectStdout;
		redirectStderr;
		run.
	process := proc.
	input := proc stdoutStream.
	output := proc stdinStream.
	isInputAliveBlock := [ process isNotNil and: [ process isRunning ] ].
	self class logToFile: 'launchTsgoAt: pid=' , ([ proc pid printString ] on: Error do: [ :_ | '<?>' ]).
	self startStderrReader.
	^ self
]

{ #category : 'accessing' }
SmallChatLSPStdioTransport >> output: aStream [
	output := aStream.
	^ self
]

{ #category : 'reading' }
SmallChatLSPStdioTransport >> parseContentLength: aHeaderString [
	"Find the Content-Length header line (case-insensitive) and return its integer value."
	| line |
	line := aHeaderString lines detect: [ :l | l asLowercase trimBoth beginsWith: 'content-length:' ].
	^ (line copyAfter: $:) trimBoth asInteger
]

{ #category : 'reading stderr' }
SmallChatLSPStdioTransport >> pumpStderrFrom: aStream while: aliveBlock [
	"Read aStream a byte at a time; flush one line to the shared log file on
	 each LF. Stops when aliveBlock returns false after a nil-read (drain-safe:
	 we call aliveBlock only when the stream has transiently no bytes). On stop,
	 any buffered partial-line bytes are flushed."
	| buf byte v |
	buf := WriteStream on: (ByteArray new: 256).
	[ true ] whileTrue: [
		byte := [ aStream next ] on: Error do: [ :_ | nil ].
		byte
			ifNotNil: [
				v := byte isInteger ifTrue: [ byte ] ifFalse: [ byte asInteger ].
				v = 10
					ifTrue: [
						self class logToFile: 'stderr: ' , buf contents utf8Decoded.
						buf := WriteStream on: (ByteArray new: 256) ]
					ifFalse: [ v = 13 ifFalse: [ buf nextPut: v ] ] ]
			ifNil: [
				aliveBlock value
					ifTrue: [ (Delay forMilliseconds: 25) wait ]
					ifFalse: [
						buf position > 0 ifTrue: [
							self class logToFile: 'stderr: ' , buf contents utf8Decoded ].
						^ self ] ] ]
]

{ #category : 'reading' }
SmallChatLSPStdioTransport >> readBodyBytes: aLength [
	"Read exactly aLength bytes from input; raise SmallChatLSPProtocolError if
	 the stream is no longer alive before aLength bytes are delivered."
	| body byte v i |
	body := ByteArray new: aLength.
	i := 1.
	[ i > aLength ] whileFalse: [
		byte := input next.
		byte
			ifNil: [
				self isInputAlive
					ifTrue: [ waitStrategy value ]
					ifFalse: [ SmallChatLSPProtocolError signal: 'EOF mid-body' ] ]
			ifNotNil: [
				v := byte isInteger ifTrue: [ byte ] ifFalse: [ byte asInteger ].
				body at: i put: v.
				i := i + 1 ] ].
	^ body
]

{ #category : 'reading' }
SmallChatLSPStdioTransport >> readHeaderBytes [
	"Read bytes from input until \r\n\r\n. Returns the header bytes (including
	 the terminator) as a ByteArray; returns nil if the stream EOFs before any
	 byte was read (clean end-of-stream between frames); raises
	 SmallChatLSPProtocolError if EOF arrives after one or more header bytes.
	 Character/Integer values are normalised -- OSSPipe next yields Characters,
	 ReadStream on ByteArray yields Integers."
	| buf byte v |
	buf := WriteStream on: (ByteArray new: 128).
	[
		byte := input next.
		byte
			ifNil: [
				self isInputAlive
					ifTrue: [ waitStrategy value ]
					ifFalse: [
						^ buf position = 0
							ifTrue: [ nil ]
							ifFalse: [ SmallChatLSPProtocolError signal: 'EOF mid-header' ] ] ]
			ifNotNil: [
				v := byte isInteger ifTrue: [ byte ] ifFalse: [ byte asInteger ].
				buf nextPut: v.
				(buf position >= 4
					and: [ (buf originalContents copyFrom: buf position - 3 to: buf position) = #[13 10 13 10] ])
					ifTrue: [ ^ buf contents ] ]
	] repeat
]

{ #category : 'reading' }
SmallChatLSPStdioTransport >> readMessage [
	"Read one LSP-framed JSON-RPC message from input. Returns the parsed
	 Dictionary, or nil on clean EOF between frames. Raises
	 SmallChatLSPProtocolError if EOF arrives mid-header or mid-body."
	| headerBytes contentLength body |
	headerBytes := self readHeaderBytes.
	headerBytes ifNil: [ ^ nil ].
	contentLength := self parseContentLength: headerBytes utf8Decoded.
	body := self readBodyBytes: contentLength.
	^ STONJSON fromString: body utf8Decoded
]

{ #category : 'lifecycle' }
SmallChatLSPStdioTransport >> shutdown [
	"Close child stdin to request clean exit (Spike S1: closing stdin is tsgo's
	 reliable shutdown signal). If still alive after the grace window, SIGTERM.
	 Wait briefly for the stderr forwarder to drain so last-gasp diagnostics
	 reach the log."
	| deadline stderrDeadline |
	process ifNil: [ ^ self ].
	[ process stdinStream close ] on: Error do: [ :_ | ].
	deadline := Time millisecondClockValue + 2000.
	[ process isRunning and: [ Time millisecondClockValue < deadline ] ] whileTrue: [
		(Delay forMilliseconds: 20) wait ].
	process isRunning ifTrue: [
		[ process terminate ] on: Error do: [ :_ | ] ].
	"Give the stderr reader its drain window before hard-stopping it."
	stderrDeadline := Time millisecondClockValue + 500.
	[ stderrRunning == true and: [ Time millisecondClockValue < stderrDeadline ] ] whileTrue: [
		(Delay forMilliseconds: 25) wait ].
	stderrRunning := false.
	stderrReaderProcess ifNotNil: [ :p |
		[ p terminate ] on: Error do: [ :_ | ].
		stderrReaderProcess := nil ].
	process := nil.
	^ self
]

{ #category : 'lifecycle' }
SmallChatLSPStdioTransport >> startStderrReader [
	"Fork a low-priority reader that forwards each stderr line from the child
	 to the shared log file. After the child exits, keeps reading for a short
	 drain window so trailing bytes are not lost."
	| stream alive exitDrainDeadline |
	stream := process stderrStream.
	stream ifNil: [ ^ self ].
	stderrRunning := true.
	alive := [
		stderrRunning == true and: [
			| procRef |
			procRef := process.
			(procRef isNotNil and: [ procRef isRunning ])
				ifTrue: [ exitDrainDeadline := nil. true ]
				ifFalse: [
					exitDrainDeadline ifNil: [
						exitDrainDeadline := Time millisecondClockValue + 300 ].
					Time millisecondClockValue < exitDrainDeadline ] ] ].
	stderrReaderProcess := [ self pumpStderrFrom: stream while: alive ]
		forkAt: Processor lowIOPriority
		named: 'SmallChat LSP Stderr'.
	^ self
]

{ #category : 'accessing' }
SmallChatLSPStdioTransport >> waitStrategy: aBlock [
	"Block invoked when input next returns nil but input is not atEnd -- the
	 live tsgo pipe is non-blocking, so transient starvation is normal. Tests
	 pass a no-op block; production yields or polls with a short delay."
	waitStrategy := aBlock.
	^ self
]

{ #category : 'writing' }
SmallChatLSPStdioTransport >> writeMessage: aDictionary [
	"Encode aDictionary as a JSON-RPC 2.0 message and write it in LSP framing
	 (Content-Length header + CRLFCRLF + UTF-8 JSON body) to output. Flushes
	 afterwards so pipe-backed transports deliver the bytes to the child."
	| body headerString |
	body := (STONJSON toString: aDictionary) utf8Encoded.
	headerString := String streamContents: [ :s |
		s nextPutAll: 'Content-Length: '.
		body size printOn: s.
		s nextPut: Character cr; nextPut: Character lf.
		s nextPut: Character cr; nextPut: Character lf ].
	output nextPutAll: headerString asByteArray.
	output nextPutAll: body.
	[ output flush ] on: Error do: [ :_ | ]
]
