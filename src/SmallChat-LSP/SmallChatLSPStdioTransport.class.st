Class {
	#name : 'SmallChatLSPStdioTransport',
	#superclass : 'Object',
	#instVars : [
		'output',
		'input'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'accessing' }
SmallChatLSPStdioTransport >> input: aStream [
	input := aStream.
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
	"Read exactly aLength bytes from input; raise SmallChatLSPProtocolError if the
	 stream EOFs before aLength bytes are delivered."
	| body byte |
	body := ByteArray new: aLength.
	1 to: aLength do: [ :i |
		byte := input next.
		byte ifNil: [ SmallChatLSPProtocolError signal: 'EOF mid-body' ].
		body at: i put: byte ].
	^ body
]

{ #category : 'reading' }
SmallChatLSPStdioTransport >> readHeaderBytes [
	"Read bytes from input until \r\n\r\n. Returns the header bytes (including
	 the terminator) as a ByteArray; returns nil if the stream EOFs before any
	 byte was read (clean end-of-stream between frames); raises
	 SmallChatLSPProtocolError if EOF arrives after one or more header bytes."
	| buf byte |
	buf := WriteStream on: (ByteArray new: 128).
	[
		byte := input next.
		byte ifNil: [
			^ buf position = 0
				ifTrue: [ nil ]
				ifFalse: [ SmallChatLSPProtocolError signal: 'EOF mid-header' ] ].
		buf nextPut: byte.
		(buf position >= 4
			and: [ (buf originalContents copyFrom: buf position - 3 to: buf position) = #[13 10 13 10] ])
	] whileFalse.
	^ buf contents
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

{ #category : 'writing' }
SmallChatLSPStdioTransport >> writeMessage: aDictionary [
	"Encode aDictionary as a JSON-RPC 2.0 message and write it in LSP framing
	 (Content-Length header + CRLFCRLF + UTF-8 JSON body) to output."
	| body headerString |
	body := (STONJSON toString: aDictionary) utf8Encoded.
	headerString := String streamContents: [ :s |
		s nextPutAll: 'Content-Length: '.
		body size printOn: s.
		s nextPut: Character cr; nextPut: Character lf.
		s nextPut: Character cr; nextPut: Character lf ].
	output nextPutAll: headerString asByteArray.
	output nextPutAll: body
]
