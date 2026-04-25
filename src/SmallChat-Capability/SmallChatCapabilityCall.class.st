Class {
	#name : 'SmallChatCapabilityCall',
	#superclass : 'Object',
	#instVars : [
		'capabilityName',
		'argumentsJson',
		'arguments'
	],
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'instance creation' }
SmallChatCapabilityCall class >> name: aString argumentsJson: aJsonString [
	"Construct a call. argumentsJson is the raw OpenAI-shape stringified JSON
	 (or an MCP arguments dict re-stringified) -- arguments parses lazily."
	^ self new setName: aString argumentsJson: aJsonString
]

{ #category : 'accessing' }
SmallChatCapabilityCall >> arguments [
	"Parsed arguments dictionary. Cached after first call. nil/empty json
	 means no arguments -- returns an empty dictionary."
	^ arguments ifNil: [
		(argumentsJson isNil or: [ argumentsJson isEmpty ])
			ifTrue: [ arguments := Dictionary new ]
			ifFalse: [ arguments := STONJSON fromString: argumentsJson ] ]
]

{ #category : 'accessing' }
SmallChatCapabilityCall >> argumentsJson [
	"Raw stringified-JSON arguments. Use #arguments for the parsed dict."
	^ argumentsJson
]

{ #category : 'accessing' }
SmallChatCapabilityCall >> capabilityName [
	"The capability the agent asked to invoke (e.g. 'vcs.status')."
	^ capabilityName
]

{ #category : 'private' }
SmallChatCapabilityCall >> setName: aString argumentsJson: aJsonString [
	capabilityName := aString.
	argumentsJson := aJsonString.
	^ self
]
