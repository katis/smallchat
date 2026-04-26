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

{ #category : 'private' }
SmallChatAgentProfile class >> defaultProfile [
	"Build the 'Default' profile from the current SmallChatConfig modelName
	 and the Pharo workspace's defaultSystemPrompt. Clamps the model to
	 availableModels first if the configured value isn't in the allow-list,
	 so the seed can't fail validation."
	| model |
	model := SmallChatConfig modelName.
	(self availableModels includes: model)
		ifFalse: [ model := self availableModels first ].
	^ self new
		name: 'Default';
		modelName: model;
		systemPrompt: SmallChatPharoWorkspace defaultSystemPrompt;
		yourself
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
	"Underlying mutable collection. Lazy-seeded with the in-image default
	 agent (workspace prompt + configured model) so a fresh image rebuild
	 always has at least one profile available."
	^ Profiles ifNil: [ Profiles := self seedProfiles ]
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
	"Drop the registry. Next read of #all re-seeds via #seedProfiles, so a
	 fresh image (or test) always has the in-image default agent."
	Profiles := nil
]

{ #category : 'private' }
SmallChatAgentProfile class >> seedProfiles [
	^ OrderedCollection with: self defaultProfile
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
	"Set the profile's name. If this profile is already in the class-side
	 registry, the new name must not collide with another registered
	 profile -- otherwise the registry could end up with two entries
	 sharing a key. Reads the Profiles class var directly to avoid
	 retriggering seed initialisation while the seeded profile itself is
	 being constructed."
	(Profiles notNil and: [ Profiles includes: self ]) ifTrue: [
		aStringOrNil = name ifTrue: [ ^ self ].
		aStringOrNil ifNil: [ Error signal: 'profile name must not be nil' ].
		(Profiles anySatisfy: [ :p | p ~~ self and: [ p name = aStringOrNil ] ])
			ifTrue: [ Error signal: 'duplicate profile name: ' , aStringOrNil printString ] ].
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
