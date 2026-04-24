Class {
	#name : 'SmallChatLSPStdioTransportTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

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
