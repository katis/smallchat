Class {
	#name : 'SmallChatLSPStdioTransportTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'tests - path resolution' }
SmallChatLSPStdioTransportTest >> testDefaultTsgoPathForResolvesUnderNativePreview [
	"The stdio transport knows where tsgo lives relative to a workspace root:
	   <root>/node_modules/@typescript/native-preview-darwin-arm64/lib/tsgo
	 M1 pins darwin-arm64; platform detection can follow when needed."
	| root path |
	root := '/home/example/code/juba' asFileReference.
	path := SmallChatLSPStdioTransport defaultTsgoPathFor: root.
	self assert: (path isKindOf: FileReference).
	self assert: (path pathString endsWith: 'node_modules/@typescript/native-preview-darwin-arm64/lib/tsgo').
	self assert: path parent basename equals: 'lib'.
	self assert: path parent parent basename equals: 'native-preview-darwin-arm64'
]

{ #category : 'tests - stderr' }
SmallChatLSPStdioTransportTest >> testPumpStderrFromStreamLogsEachLine [
	"pumpStderrFrom:while: reads bytes from a stream and writes one log line
	 per LF-terminated chunk via SmallChatLSPStdioTransport class>>logToFile:.
	 The test drives it with a ReadStream and an aliveBlock that turns off when
	 the stream is empty. The log seed contains a multi-byte UTF-8 char so the
	 tail extraction must operate on bytes -- mixing logFile size (byte count)
	 with logFile contents size (char count) crashes copyFrom:to: on a log that
	 already carries non-ASCII content from a previous live run."
	| transport source logFile preSize tail lf bytes nonAsciiSeed |
	logFile := Smalltalk vm imageFile parent / 'smallchat-lsp.log'.
	nonAsciiSeed := (String with: (Character codePoint: 233)) utf8Encoded.
	logFile binaryWriteStreamDo: [ :s | s setToEnd; nextPutAll: nonAsciiSeed ].
	preSize := logFile size.
	transport := SmallChatLSPStdioTransport new.
	lf := (String with: Character lf) asByteArray.
	bytes := 'abc' asByteArray , lf , 'def' asByteArray , lf.
	source := ReadStream on: bytes.
	transport pumpStderrFrom: source while: [ source atEnd not ].
	self assert: logFile exists.
	tail := (logFile binaryReadStreamDo: [ :s | s skip: preSize. s upToEnd ]) utf8Decoded.
	self assert: (tail includesSubstring: 'stderr: abc').
	self assert: (tail includesSubstring: 'stderr: def')
]

{ #category : 'tests - framing' }
SmallChatLSPStdioTransportTest >> testReadDecodesSingleFrame [
	"readMessage parses a single well-formed Content-Length frame and returns the
	 message as a Dictionary with the JSON-RPC envelope fields."
	| message body header frame transport source |
	message := Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'id' put: 7;
		at: 'method' put: 'initialize';
		yourself.
	body := (STONJSON toString: message) utf8Encoded.
	header := String streamContents: [ :s |
		s nextPutAll: 'Content-Length: '.
		body size printOn: s.
		s nextPut: Character cr; nextPut: Character lf.
		s nextPut: Character cr; nextPut: Character lf ].
	frame := header asByteArray , body.
	source := ReadStream on: frame.
	transport := SmallChatLSPStdioTransport new input: source.
	self assert: transport readMessage equals: message
]

{ #category : 'tests - framing' }
SmallChatLSPStdioTransportTest >> testReadRaisesOnTruncatedFrame [
	"A stream that EOFs in the middle of a frame is a protocol violation --
	 readMessage must raise SmallChatLSPProtocolError so the reader loop can
	 surface the condition rather than silently dropping a message."
	| truncated transport |
	truncated := 'Content-Length: 10' asByteArray.
	transport := SmallChatLSPStdioTransport new input: (ReadStream on: truncated).
	self should: [ transport readMessage ] raise: SmallChatLSPProtocolError
]

{ #category : 'tests - framing' }
SmallChatLSPStdioTransportTest >> testReadReturnsNilOnCleanEof [
	"readMessage on an empty/exhausted stream returns nil -- this signals
	 end-of-stream between frames, distinct from a protocol error."
	| transport |
	transport := SmallChatLSPStdioTransport new input: (ReadStream on: #[]).
	self assert: transport readMessage isNil
]

{ #category : 'tests - framing' }
SmallChatLSPStdioTransportTest >> testReadToleratesNilPollsBeforeBodyComplete [
	"A stream that returns nil transiently (data not yet available) while still
	 not atEnd must NOT be treated as EOF. The transport calls its waitStrategy
	 and keeps reading once bytes arrive."
	| message body header frame source calls transport |
	message := Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'id' put: 11;
		at: 'method' put: 'ping';
		yourself.
	body := (STONJSON toString: message) utf8Encoded.
	header := String streamContents: [ :s |
		s nextPutAll: 'Content-Length: '.
		body size printOn: s.
		s nextPut: Character cr; nextPut: Character lf.
		s nextPut: Character cr; nextPut: Character lf ].
	frame := header asByteArray , body.
	source := SmallChatLSPTestIntermittentStream new
		nilStride: 2;
		contents: frame;
		yourself.
	calls := 0.
	transport := SmallChatLSPStdioTransport new
		input: source;
		waitStrategy: [ calls := calls + 1 ];
		yourself.
	self assert: transport readMessage equals: message.
	self assert: calls > 0
]

{ #category : 'tests - framing' }
SmallChatLSPStdioTransportTest >> testReadTwoFramesReturnsBoth [
	"Successive readMessage calls on a stream that holds two concatenated
	 Content-Length frames each return the respective message."
	| encodeFrame first second source transport |
	encodeFrame := [ :aDictionary |
		| body header |
		body := (STONJSON toString: aDictionary) utf8Encoded.
		header := String streamContents: [ :s |
			s nextPutAll: 'Content-Length: '.
			body size printOn: s.
			s nextPut: Character cr; nextPut: Character lf.
			s nextPut: Character cr; nextPut: Character lf ].
		header asByteArray , body ].
	first := Dictionary new at: 'jsonrpc' put: '2.0'; at: 'id' put: 1; at: 'method' put: 'initialize'; yourself.
	second := Dictionary new at: 'jsonrpc' put: '2.0'; at: 'id' put: 2; at: 'method' put: 'shutdown'; yourself.
	source := ReadStream on: ((encodeFrame value: first) , (encodeFrame value: second)).
	transport := SmallChatLSPStdioTransport new input: source.
	self assert: transport readMessage equals: first.
	self assert: transport readMessage equals: second
]

{ #category : 'tests - resolution' }
SmallChatLSPStdioTransportTest >> testResolveTsgoErrorsWhenMissing [
	"With no node_modules and the pnpm probe stubbed off, resolveTsgoCommandIn:
	 must raise an Error that names the workspace path so the agent knows where
	 to install tsgo."
	| tmpRoot |
	tmpRoot := FileLocator temp asFileReference / ('smallchat-tsgo-missing-' , UUID new asString36).
	tmpRoot ensureCreateDirectory.
	[
		SmallChatLSPStdioTransport pnpmTsgoProbeBlock: [ :_ | false ].
		[
			self
				should: [ SmallChatLSPStdioTransport resolveTsgoCommandIn: tmpRoot ]
				raise: Error
				withExceptionDo: [ :e |
					self assert: (e messageText includesSubstring: 'tsgo').
					self assert: (e messageText includesSubstring: tmpRoot pathString) ]
		] ensure: [ SmallChatLSPStdioTransport resetPnpmTsgoProbeBlock ]
	] ensure: [ tmpRoot exists ifTrue: [ tmpRoot deleteAll ] ]
]

{ #category : 'tests - resolution' }
SmallChatLSPStdioTransportTest >> testResolveTsgoFindsLocalNodeModulesBin [
	"Happy path: a workspace with tsgo installed at node_modules/.bin/tsgo
	 resolves to that exact path -- proving the rule reaches the workspace
	 tree and never falls through to a global PATH lookup."
	| tmpRoot binDir tsgoFile resolved |
	tmpRoot := FileLocator temp asFileReference / ('smallchat-tsgo-resolve-' , UUID new asString36).
	tmpRoot ensureCreateDirectory.
	[
		binDir := tmpRoot / 'node_modules' / '.bin'.
		binDir ensureCreateDirectory.
		tsgoFile := binDir / 'tsgo'.
		tsgoFile writeStreamDo: [ :s | s nextPutAll: '#!/bin/sh' ].
		"Stub the pnpm probe to ALWAYS true so any miss would silently fall
		 through to it -- this asserts the local-bin path takes precedence."
		SmallChatLSPStdioTransport pnpmTsgoProbeBlock: [ :_ | true ].
		[
			resolved := SmallChatLSPStdioTransport resolveTsgoCommandIn: tmpRoot.
			self assert: (resolved isKindOf: SequenceableCollection).
			self assert: resolved first equals: tsgoFile fullName
		] ensure: [ SmallChatLSPStdioTransport resetPnpmTsgoProbeBlock ]
	] ensure: [ tmpRoot exists ifTrue: [ tmpRoot deleteAll ] ]
]

{ #category : 'tests - framing' }
SmallChatLSPStdioTransportTest >> testWriteEncodesContentLengthFrame [
	"Writing a JSON-RPC message must emit a LSP-style header plus body:
	   Content-Length: N\r\n\r\n<utf8-json>
	 where N is the byte count of the UTF-8 encoded JSON body."
	| sink transport message bytes asString headerEnd declaredLength body |
	sink := WriteStream on: (ByteArray new: 128).
	transport := SmallChatLSPStdioTransport new output: sink.
	message := Dictionary new
		at: 'jsonrpc' put: '2.0';
		at: 'id' put: 1;
		at: 'method' put: 'initialize';
		at: 'params' put: Dictionary new;
		yourself.
	transport writeMessage: message.
	bytes := sink contents.
	asString := bytes utf8Decoded.
	headerEnd := asString indexOfSubCollection: (String with: Character cr with: Character lf with: Character cr with: Character lf).
	self assert: headerEnd > 0.
	declaredLength := ((asString copyFrom: 1 to: headerEnd - 1) copyAfter: $:) trimBoth asInteger.
	body := bytes copyFrom: headerEnd + 4 to: bytes size.
	self assert: body size equals: declaredLength.
	self assert: (STONJSON fromString: body utf8Decoded) equals: message
]
