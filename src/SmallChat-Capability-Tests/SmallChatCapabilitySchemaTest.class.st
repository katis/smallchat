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
