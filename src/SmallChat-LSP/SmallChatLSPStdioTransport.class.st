Class {
	#name : 'SmallChatLSPStdioTransport',
	#superclass : 'Object',
	#instVars : [
		'output'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'accessing' }
SmallChatLSPStdioTransport >> output: aStream [
	output := aStream.
	^ self
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
