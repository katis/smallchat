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
SmallChatNavShowMethodTest >> testShowsMethodHeaderAndSource [
	| result |
	result := SmallChatNav show: #SmallChatLMSession method: #sendUserInput:.
	self assert: (result includesSubstring: 'SmallChatLMSession>>sendUserInput:').
	self assert: (result includesSubstring: '```smalltalk')
]
