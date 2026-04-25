Class {
	#name : 'SmallChatCapabilityResult',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'text'
	],
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'instance creation' }
SmallChatCapabilityResult class >> text: aString [
	"Construct a text-shaped result. The most common variant: any
	 capability returning a printable string, JSON-encoded payload, etc."
	^ self new setKind: #text text: aString
]

{ #category : 'accessing' }
SmallChatCapabilityResult >> kind [
	"#text / #json / #image / #debugSession / #error. Discriminator for
	 transport-side rendering."
	^ kind
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
