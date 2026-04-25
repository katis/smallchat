Class {
	#name : 'SmallChatCapabilityRegistryTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testAllCapabilitiesExcludesAbstractBase [
	"Reflective discovery filters the abstract SmallChatCapability."
	self deny: (SmallChatCapabilityRegistry default allCapabilities includes: SmallChatCapability)
]

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testAllCapabilitiesIncludesConcreteSubclass [
	"Concrete subclasses appear automatically."
	self assert: (SmallChatCapabilityRegistry default allCapabilities
		includes: SmallChatCapabilityFakeStatusForTests)
]

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testCapabilityNamedReturnsMatching [
	"Lookup by capabilityName -- the agent-facing identifier."
	self assert: (SmallChatCapabilityRegistry default capabilityNamed: 'test.fake.status')
		== SmallChatCapabilityFakeStatusForTests
]

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testCapabilityNamedReturnsNilForUnknown [
	self assert: (SmallChatCapabilityRegistry default capabilityNamed: 'nope.does-not-exist') isNil
]
