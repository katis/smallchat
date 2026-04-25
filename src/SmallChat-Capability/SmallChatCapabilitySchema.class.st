Class {
	#name : 'SmallChatCapabilitySchema',
	#superclass : 'Object',
	#instVars : [
		'fields'
	],
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'instance creation' }
SmallChatCapabilitySchema class >> empty [
	"Schema with no fields. Use for capabilities that take no arguments."
	^ self new
]

{ #category : 'emitting' }
SmallChatCapabilitySchema >> asJsonSchema [
	"Emit a JSON Schema dictionary matching today's SmallChatTool>>inputSchema
	 shape: { type: 'object', properties: { ... }, required: #(...) }."
	| properties required |
	properties := Dictionary new.
	required := OrderedCollection new.
	fields do: [ :f |
		properties at: f name put: f asJsonSchemaProperty.
		f required ifTrue: [ required add: f name ] ].
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: properties;
		at: 'required' put: required asArray;
		yourself
]

{ #category : 'emitting' }
SmallChatCapabilitySchema >> asOpenAIFunctionSchemaName: aName description: aDescription [
	"Wrap #asJsonSchema in OpenAI function-calling tool schema shape:
	 { type: 'function', function: { name, description, parameters: <jsonSchema> } }.
	 The LM-native catalog calls this once per registered capability."
	| fn |
	fn := Dictionary new
		at: 'name' put: aName;
		at: 'description' put: aDescription;
		at: 'parameters' put: self asJsonSchema;
		yourself.
	^ Dictionary new
		at: 'type' put: 'function';
		at: 'function' put: fn;
		yourself
]

{ #category : 'building' }
SmallChatCapabilitySchema >> boolean: aName required: aBoolean description: aDescription [
	"Append a #boolean field. Same shape as #string:required:description:."
	fields add: (SmallChatCapabilitySchemaField
		name: aName
		type: #boolean
		required: aBoolean
		description: aDescription).
	^ self
]

{ #category : 'accessing' }
SmallChatCapabilitySchema >> fields [
	"Ordered collection of SmallChatCapabilitySchemaField. Order is the
	 declaration order; emitters preserve it for natural rendering."
	^ fields
]

{ #category : 'initialization' }
SmallChatCapabilitySchema >> initialize [
	super initialize.
	fields := OrderedCollection new
]

{ #category : 'building' }
SmallChatCapabilitySchema >> string: aName required: aBoolean description: aDescription [
	"Append a #string field. Returns self so callers can chain."
	fields add: (SmallChatCapabilitySchemaField
		name: aName
		type: #string
		required: aBoolean
		description: aDescription).
	^ self
]
