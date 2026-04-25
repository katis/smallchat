Class {
	#name : 'SmallChatCapabilitySchemaTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests-emitters' }
SmallChatCapabilitySchemaTest >> testArrayOfStringFieldBuilder [
	"#array:of:required:description: appends an #array field whose items
	 carry the inner type. Emits {type: 'array', items: {type: <inner>}, description}."
	| s json prop |
	s := SmallChatCapabilitySchema empty
		array: 'paths'
		of: #string
		required: true
		description: 'Repo-relative paths'.
	json := s asJsonSchema.
	prop := (json at: 'properties') at: 'paths'.
	self assert: (prop at: 'type') equals: 'array'.
	self assert: ((prop at: 'items') at: 'type') equals: 'string'.
	self assert: (prop at: 'description') equals: 'Repo-relative paths'.
	self assert: (json at: 'required') asArray equals: #('paths')
]

{ #category : 'tests-emitters' }
SmallChatCapabilitySchemaTest >> testBooleanFieldBuilder [
	"#boolean:required:description: appends a #boolean field that emits as
	 {type: 'boolean'} in the JSON Schema property."
	| s json prop |
	s := SmallChatCapabilitySchema empty
		boolean: 'debug_first_failure'
		required: false
		description: 'Re-run the first failing test under the debug evaluator'.
	json := s asJsonSchema.
	prop := (json at: 'properties') at: 'debug_first_failure'.
	self assert: (prop at: 'type') equals: 'boolean'.
	self assert: (prop at: 'description') equals: 'Re-run the first failing test under the debug evaluator'.
	self assert: (json at: 'required') asArray equals: #()
]

{ #category : 'tests-emitters' }
SmallChatCapabilitySchemaTest >> testEmptySchemaEmitsObjectWithEmptyPropertiesAndRequired [
	"Matches today's no-arg SmallChatTool>>inputSchema shape exactly."
	| s |
	s := SmallChatCapabilitySchema empty asJsonSchema.
	self assert: (s at: 'type') equals: 'object'.
	self assert: (s at: 'properties') isEmpty.
	self assert: (s at: 'required') asArray equals: #()
]

{ #category : 'tests' }
SmallChatCapabilitySchemaTest >> testEmptySchemaHasNoFields [
	"Capabilities that take no arguments use SmallChatCapabilitySchema empty."
	self assert: SmallChatCapabilitySchema empty fields isEmpty
]

{ #category : 'tests-emitters' }
SmallChatCapabilitySchemaTest >> testIntegerFieldBuilder [
	"#integer:required:description: appends a #integer field that emits as
	 {type: 'integer'} in the JSON Schema property."
	| s json prop |
	s := SmallChatCapabilitySchema empty
		integer: 'index'
		required: true
		description: 'Frame index to inspect'.
	json := s asJsonSchema.
	prop := (json at: 'properties') at: 'index'.
	self assert: (prop at: 'type') equals: 'integer'.
	self assert: (json at: 'required') asArray equals: #('index')
]

{ #category : 'tests-emitters' }
SmallChatCapabilitySchemaTest >> testOpenAIFunctionSchemaWrapsJsonSchema [
	"Matches OpenAI function-call tool schema shape:
	 { type: 'function', function: { name, description, parameters: <jsonSchema> } }"
	| s schema fn |
	s := SmallChatCapabilitySchema empty
		string: 'code'
		required: true
		description: 'Smalltalk to evaluate'.
	schema := s asOpenAIFunctionSchemaName: 'eval.smalltalk' description: 'Run Smalltalk in the live image'.
	self assert: (schema at: 'type') equals: 'function'.
	fn := schema at: 'function'.
	self assert: (fn at: 'name') equals: 'eval.smalltalk'.
	self assert: (fn at: 'description') equals: 'Run Smalltalk in the live image'.
	self assert: (fn at: 'parameters') equals: s asJsonSchema
]

{ #category : 'tests-emitters' }
SmallChatCapabilitySchemaTest >> testOptionalFieldExcludedFromRequired [
	"Optional fields appear in #properties but not in the #required list."
	| s json |
	s := SmallChatCapabilitySchema empty
		string: 'packagePattern'
		required: false
		description: 'Default SmallChat.*'.
	json := s asJsonSchema.
	self assert: ((json at: 'properties') includesKey: 'packagePattern').
	self assert: (json at: 'required') asArray equals: #()
]

{ #category : 'tests-emitters' }
SmallChatCapabilitySchemaTest >> testRequiredStringFieldEmitsCorrectJsonSchema [
	"Required scalar lands in #required; per-property carries type + description."
	| s json props |
	s := SmallChatCapabilitySchema empty
		string: 'code'
		required: true
		description: 'Smalltalk to evaluate'.
	json := s asJsonSchema.
	props := json at: 'properties'.
	self assert: (props at: 'code') size equals: 2.
	self assert: ((props at: 'code') at: 'type') equals: 'string'.
	self assert: ((props at: 'code') at: 'description') equals: 'Smalltalk to evaluate'.
	self assert: (json at: 'required') asArray equals: #('code')
]

{ #category : 'tests' }
SmallChatCapabilitySchemaTest >> testStringFieldBuilderAppendsField [
	"#string:required:description: appends a SmallChatCapabilitySchemaField
	 of type #string in declaration order. Returns self for chaining."
	| s |
	s := SmallChatCapabilitySchema empty
		string: 'code'
		required: true
		description: 'Smalltalk to evaluate'.
	self assert: s fields size equals: 1.
	self assert: s fields first name equals: 'code'.
	self assert: s fields first type equals: #string.
	self assert: s fields first required.
	self assert: s fields first description equals: 'Smalltalk to evaluate'
]
