Class {
	#name : 'SmallChatCapabilitySchemaTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatCapabilitySchemaTest >> testEmptySchemaHasNoFields [
	"Capabilities that take no arguments use SmallChatCapabilitySchema empty."
	self assert: SmallChatCapabilitySchema empty fields isEmpty
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
