Class {
	#name : 'SmallChatCapabilityResultTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests-lm' }
SmallChatCapabilityResultTest >> testAsTextForLMRendersErrorResult [
	self assert: (SmallChatCapabilityResult error: 'boom') asTextForLM equals: 'boom'
]

{ #category : 'tests-lm' }
SmallChatCapabilityResultTest >> testAsTextForLMRendersImagePlaceholder [
	| r |
	r := SmallChatCapabilityResult image: #(0 1 2) asByteArray mimeType: 'image/png'.
	self assert: r asTextForLM equals: '<image:image/png 3 bytes>'
]

{ #category : 'tests-lm' }
SmallChatCapabilityResultTest >> testAsTextForLMRendersTextResult [
	self assert: (SmallChatCapabilityResult text: 'hi') asTextForLM equals: 'hi'
]

{ #category : 'tests' }
SmallChatCapabilityResultTest >> testDebugSessionResultCarriesSession [
	"The captured debug session is a SmallChatDebugSession (registry id, etc.).
	 Transport renders it differently from text."
	| stub r |
	stub := Object new.
	r := SmallChatCapabilityResult debugSession: stub.
	self assert: r kind equals: #debugSession.
	self assert: r debugSession == stub
]

{ #category : 'tests' }
SmallChatCapabilityResultTest >> testErrorResultCarriesTextWithErrorKind [
	| r |
	r := SmallChatCapabilityResult error: 'boom'.
	self assert: r kind equals: #error.
	self assert: r text equals: 'boom'
]

{ #category : 'tests' }
SmallChatCapabilityResultTest >> testImageResultCarriesBytesAndMimeType [
	| bytes r |
	bytes := #(137 80 78 71) asByteArray.
	r := SmallChatCapabilityResult image: bytes mimeType: 'image/png'.
	self assert: r kind equals: #image.
	self assert: r bytes equals: bytes.
	self assert: r mimeType equals: 'image/png'
]

{ #category : 'tests' }
SmallChatCapabilityResultTest >> testTextResultCarriesText [
	| r |
	r := SmallChatCapabilityResult text: 'hi'.
	self assert: r kind equals: #text.
	self assert: r text equals: 'hi'
]
