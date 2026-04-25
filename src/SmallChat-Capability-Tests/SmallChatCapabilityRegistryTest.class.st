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

{ #category : 'tests' }
SmallChatCapabilityRegistryTest >> testRunDispatchesToCapability [
	"#run:with: looks up the capability by name and forwards aCall to its
	 class-side #run:."
	| call result |
	call := SmallChatCapabilityCall name: 'test.fake.status' argumentsJson: ''.
	result := SmallChatCapabilityRegistry default run: 'test.fake.status' with: call.
	self assert: result kind equals: #text.
	self assert: result text equals: 'ok'
]
