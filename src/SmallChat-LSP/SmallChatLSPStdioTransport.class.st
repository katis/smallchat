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
SmallChatLSPStdioTransport >> readMessage [
	"Read one LSP-framed JSON-RPC message from input. Returns the parsed
	 Dictionary. Assumes a well-formed frame and a stream that will not starve;
	 EOF and partial-data handling arrive in later steps."
	| buf byte contentLength body header lengthLine |
	buf := WriteStream on: (ByteArray new: 128).
	[ byte := input next.
	  buf nextPut: byte.
	  (buf position < 4) or: [
		((buf originalContents copyFrom: buf position - 3 to: buf position) ~= #[13 10 13 10]) ] ]
		whileTrue.
	header := buf contents utf8Decoded.
	lengthLine := header lines detect: [ :l | l asLowercase trimBoth beginsWith: 'content-length:' ].
	contentLength := (lengthLine copyAfter: $:) trimBoth asInteger.
	body := ByteArray new: contentLength.
	1 to: contentLength do: [ :i | body at: i put: input next ].
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
