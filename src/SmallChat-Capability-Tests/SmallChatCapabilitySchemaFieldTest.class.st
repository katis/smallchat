Class {
	#name : 'SmallChatCapabilitySchemaFieldTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatCapabilitySchemaFieldTest >> testFieldCarriesNameTypeRequiredDescription [
	| f |
	f := SmallChatCapabilitySchemaField
		name: 'code'
		type: #string
		required: true
		description: 'Smalltalk to evaluate'.
	self assert: f name equals: 'code'.
	self assert: f type equals: #string.
	self assert: f required.
	self assert: f description equals: 'Smalltalk to evaluate'
]
