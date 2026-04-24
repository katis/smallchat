Class {
	#name : 'SmallChatLSPStdioTransport',
	#superclass : 'Object',
	#instVars : [
		'output',
		'input',
		'waitStrategy',
		'process',
		'isInputAliveBlock'
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
	"Spawn tsgo --lsp --stdio under aWorkspaceRoot and wire input/output to the
	 child's stdout/stdin. Raises on missing binary or missing OSSubprocess."
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
	"Close child stdin to request clean exit (tsgo ignores LSP shutdown/exit;
	 closing stdin is the reliable signal per Spike S1). If still alive after
	 a short grace period, SIGTERM."
	| deadline |
	process ifNil: [ ^ self ].
	[ process stdinStream close ] on: Error do: [ :_ | ].
	deadline := Time millisecondClockValue + 2000.
	[ process isRunning and: [ Time millisecondClockValue < deadline ] ] whileTrue: [
		(Delay forMilliseconds: 20) wait ].
	process isRunning ifTrue: [
		[ process terminate ] on: Error do: [ :_ | ] ].
	process := nil.
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
