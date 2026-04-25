Class {
	#name : 'SmallChatCapabilityResult',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'text',
		'debugSession',
		'bytes',
		'mimeType'
	],
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'instance creation' }
SmallChatCapabilityResult class >> debugSession: aSmallChatDebugSession [
	"Construct a debug-session-shaped result. Carried object is the
	 SmallChatDebugSession the evaluator captured; transport renders the
	 reply with id + frame metadata so the agent can drive debug_*."
	| r |
	r := self new.
	r setKind: #debugSession text: nil.
	r privateDebugSession: aSmallChatDebugSession.
	^ r
]

{ #category : 'instance creation' }
SmallChatCapabilityResult class >> error: aString [
	"Construct an error-shaped result. Carried text is the human-readable
	 message; transports flag the result with their error envelope."
	^ self new setKind: #error text: aString
]

{ #category : 'instance creation' }
SmallChatCapabilityResult class >> image: aByteArray mimeType: aMimeTypeString [
	"Construct an image-shaped result. Bytes are raw image data (PNG/SVG/...);
	 mime type tells transports how to label the payload (image/png,
	 image/svg+xml, ...). MCP transport base64-encodes the bytes."
	| r |
	r := self new.
	r setKind: #image text: nil.
	r privateBytes: aByteArray mimeType: aMimeTypeString.
	^ r
]

{ #category : 'instance creation' }
SmallChatCapabilityResult class >> text: aString [
	"Construct a text-shaped result. The most common variant: any
	 capability returning a printable string, JSON-encoded payload, etc."
	^ self new setKind: #text text: aString
]

{ #category : 'accessing' }
SmallChatCapabilityResult >> bytes [
	"Raw bytes for #image results, nil otherwise."
	^ bytes
]

{ #category : 'accessing' }
SmallChatCapabilityResult >> debugSession [
	"SmallChatDebugSession instance for #debugSession results, nil otherwise."
	^ debugSession
]

{ #category : 'accessing' }
SmallChatCapabilityResult >> kind [
	"#text / #json / #image / #debugSession / #error. Discriminator for
	 transport-side rendering."
	^ kind
]

{ #category : 'accessing' }
SmallChatCapabilityResult >> mimeType [
	"MIME type for #image results, nil otherwise."
	^ mimeType
]

{ #category : 'private' }
SmallChatCapabilityResult >> privateBytes: aByteArray mimeType: aString [
	bytes := aByteArray.
	mimeType := aString
]

{ #category : 'private' }
SmallChatCapabilityResult >> privateDebugSession: aSession [
	debugSession := aSession
]

{ #category : 'private' }
SmallChatCapabilityResult >> setKind: aSymbol text: aString [
	kind := aSymbol.
	text := aString.
	^ self
]

{ #category : 'accessing' }
SmallChatCapabilityResult >> text [
	"Text payload for #text / #error variants. nil otherwise."
	^ text
]
