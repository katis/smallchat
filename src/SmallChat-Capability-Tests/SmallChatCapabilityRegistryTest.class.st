Class {
	#name : 'SmallChatCapabilityRegistryTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testAllCapabilitiesIsEmptyWithNoConcreteSubclasses [
	"With only the abstract SmallChatCapability defined, the registry has
	 no concrete capabilities to discover."
	self assert: SmallChatCapabilityRegistry default allCapabilities asArray equals: #()
]
