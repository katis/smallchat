Class {
	#name : 'SmallChatAgentProfile',
	#superclass : 'Object',
	#instVars : [
		'name',
		'modelName',
		'systemPrompt'
	],
	#classVars : [
		'Profiles'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatAgentProfile class >> add: aProfile [
	"Append aProfile to the registry. Names must be present and unique."
	aProfile name ifNil: [ Error signal: 'profile name required' ].
	(self profilesCollection anySatisfy: [ :each | each name = aProfile name ])
		ifTrue: [ Error signal: 'duplicate profile name: ' , aProfile name printString ].
	self profilesCollection add: aProfile.
	^ aProfile
]

{ #category : 'accessing' }
SmallChatAgentProfile class >> all [
	"A copy of the registered profiles, in insertion order."
	^ self profilesCollection copy
]

{ #category : 'accessing' }
SmallChatAgentProfile class >> availableModels [
	"The model names the editor offers in its drop-list. Single source of
	 truth -- new profiles default to the first entry, and the registry's
	 seed clamps unknown values to it."
	^ #('Qwen3.6-27B-MLX-8bit' 'Qwen3.6-35B-A3B-nvfp4')
]

{ #category : 'accessing' }
SmallChatAgentProfile class >> named: aString [
	^ self named: aString ifAbsent: [ Error signal: 'no profile named ' , aString printString ]
]

{ #category : 'accessing' }
SmallChatAgentProfile class >> named: aString ifAbsent: aBlock [
	^ self profilesCollection
		detect: [ :each | each name = aString ]
		ifNone: aBlock
]

{ #category : 'private' }
SmallChatAgentProfile class >> profilesCollection [
	"Underlying mutable collection. Slice 5 will replace this body with a
	 lazy-seeding variant; for now it's an empty bag on first access."
	^ Profiles ifNil: [ Profiles := OrderedCollection new ]
]

{ #category : 'accessing' }
SmallChatAgentProfile class >> removeNamed: aString [
	"Remove and return the profile with this name; raises if absent."
	| match |
	match := self named: aString.
	self profilesCollection remove: match.
	^ match
]

{ #category : 'class initialization' }
SmallChatAgentProfile class >> reset [
	"Drop everything in the registry. Tests call this in setUp/tearDown."
	Profiles := OrderedCollection new
]

{ #category : 'initialization' }
SmallChatAgentProfile >> initialize [
	super initialize.
	modelName := self class availableModels first.
	systemPrompt := ''
]

{ #category : 'accessing' }
SmallChatAgentProfile >> modelName [
	^ modelName
]

{ #category : 'accessing' }
SmallChatAgentProfile >> modelName: aString [
	(self class availableModels includes: aString)
		ifFalse: [ Error signal: 'Unknown model: ' , aString printString ].
	modelName := aString
]

{ #category : 'accessing' }
SmallChatAgentProfile >> name [
	^ name
]

{ #category : 'accessing' }
SmallChatAgentProfile >> name: aStringOrNil [
	name := aStringOrNil
]

{ #category : 'accessing' }
SmallChatAgentProfile >> systemPrompt [
	^ systemPrompt
]

{ #category : 'accessing' }
SmallChatAgentProfile >> systemPrompt: aString [
	systemPrompt := aString
]
