Class {
	#name : 'SmallChatLMCapabilityCatalog',
	#superclass : 'Object',
	#classInstVars : [
		'default'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatLMCapabilityCatalog class >> default [
	"Singleton catalog. Reset via #reset for tests."
	^ default ifNil: [ default := self new ]
]

{ #category : 'accessing' }
SmallChatLMCapabilityCatalog class >> reset [
	default := nil
]

{ #category : 'accessing' }
SmallChatLMCapabilityCatalog >> toolSchemas [
	"One OpenAI-function schema per registered production capability.
	 Test fixtures (#isTestFixture true) are filtered out so they never
	 reach the LM. Returned as Array (STONJSON requires Array, not
	 OrderedCollection)."
	^ ((SmallChatCapabilityRegistry default allCapabilities
		reject: [ :cap | cap isTestFixture ])
		collect: [ :cap |
			cap schema
				asOpenAIFunctionSchemaName: cap capabilityName
				description: cap description ]) asArray
]
