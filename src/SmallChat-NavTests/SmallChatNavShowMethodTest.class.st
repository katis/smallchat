Class {
	#name : 'SmallChatNavShowMethodTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-NavTests',
	#package : 'SmallChat-NavTests'
}

{ #category : 'tests' }
SmallChatNavShowMethodTest >> testNotFoundReturnsLabelWhenClassMissing [
	| result |
	result := SmallChatNav show: #ThisClassNameDoesNotExistAnywhere method: #foo.
	self assert: (result includesSubstring: '_class not found:')
]

{ #category : 'tests' }
SmallChatNavShowMethodTest >> testNotFoundReturnsLabelWhenMethodMissing [
	| result |
	result := SmallChatNav show: #SmallChatLMSession method: #thisMethodNeverExisted.
	self assert: (result includesSubstring: '_method not found:')
]

{ #category : 'tests' }
SmallChatNavShowMethodTest >> testShowsClassSideMethodWhenInstanceSideMissing [
	"A class-side selector (e.g. SmallChatNav class>>describeClass:) must be
	 reachable even though it's not on the instance side. The header tags
	 the class side so the agent knows the call shape."
	| result |
	result := SmallChatNav show: #SmallChatNav method: #describeClass:.
	self assert: (result includesSubstring: 'SmallChatNav class>>describeClass:').
	self assert: (result includesSubstring: '```smalltalk')
]

{ #category : 'tests' }
SmallChatNavShowMethodTest >> testShowsMethodHeaderAndSource [
	| result |
	result := SmallChatNav show: #SmallChatLMSession method: #sendUserInput:.
	self assert: (result includesSubstring: 'SmallChatLMSession>>sendUserInput:').
	self assert: (result includesSubstring: '```smalltalk')
]
