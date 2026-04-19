"
Value object returned by SmallChatTool subclasses that need to deliver
richer content than a plain String. The registry unwraps an instance
into the MCP tool-result content array.

A tool's #run: may return either a String (treated as text) or a
SmallChatToolResult (text or image).
"
Class {
	#name : #SmallChatToolResult,
	#superclass : #Object,
	#instVars : [
		'kind',
		'mimeType',
		'bytes',
		'text'
	],
	#category : #'SmallChat-MCP'
}

{ #category : #'instance creation' }
SmallChatToolResult class >> image: aByteArray mimeType: aMimeType [
	^ self new
		kind: #image;
		bytes: aByteArray;
		mimeType: aMimeType;
		yourself
]

{ #category : #'instance creation' }
SmallChatToolResult class >> png: aByteArray [
	^ self image: aByteArray mimeType: 'image/png'
]

{ #category : #'instance creation' }
SmallChatToolResult class >> svg: aStringOrBytes [
	^ self image: aStringOrBytes asByteArray mimeType: 'image/svg+xml'
]

{ #category : #'instance creation' }
SmallChatToolResult class >> text: aString [
	^ self new
		kind: #text;
		text: aString;
		yourself
]

{ #category : #accessing }
SmallChatToolResult >> bytes [
	^ bytes
]

{ #category : #accessing }
SmallChatToolResult >> bytes: aByteArray [
	bytes := aByteArray
]

{ #category : #accessing }
SmallChatToolResult >> kind [
	^ kind
]

{ #category : #accessing }
SmallChatToolResult >> kind: aSymbol [
	kind := aSymbol
]

{ #category : #accessing }
SmallChatToolResult >> mimeType [
	^ mimeType
]

{ #category : #accessing }
SmallChatToolResult >> mimeType: aString [
	mimeType := aString
]

{ #category : #accessing }
SmallChatToolResult >> text [
	^ text
]

{ #category : #accessing }
SmallChatToolResult >> text: aString [
	text := aString
]

{ #category : #conversion }
SmallChatToolResult >> toMcpContentDict [
	"Return the single-item MCP content dictionary for this result."
	kind = #text ifTrue: [
		^ Dictionary new
			at: 'type' put: 'text';
			at: 'text' put: text asString;
			yourself ].
	kind = #image ifTrue: [
		^ Dictionary new
			at: 'type' put: 'image';
			at: 'mimeType' put: mimeType;
			at: 'data' put: bytes base64Encoded;
			yourself ].
	^ self error: 'Unknown SmallChatToolResult kind: ', kind printString
]
