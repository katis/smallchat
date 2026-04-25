Class {
	#name : 'SmallChatCapabilityResultTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatCapabilityResultTest >> testErrorResultCarriesTextWithErrorKind [
	| r |
	r := SmallChatCapabilityResult error: 'boom'.
	self assert: r kind equals: #error.
	self assert: r text equals: 'boom'
]

{ #category : 'tests' }
SmallChatCapabilityResultTest >> testTextResultCarriesText [
	| r |
	r := SmallChatCapabilityResult text: 'hi'.
	self assert: r kind equals: #text.
	self assert: r text equals: 'hi'
]
