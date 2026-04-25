Class {
	#name : 'SmallChatNavFindClassesTest',
	#superclass : 'TestCase',
	#instVars : [
		'savedBudget'
	],
	#category : 'SmallChat-NavTests',
	#package : 'SmallChat-NavTests'
}

{ #category : 'running' }
SmallChatNavFindClassesTest >> setUp [
	super setUp.
	savedBudget := SmallChatNavBudget default size
]

{ #category : 'running' }
SmallChatNavFindClassesTest >> tearDown [
	SmallChatNavBudget default size: savedBudget.
	super tearDown
]

{ #category : 'tests' }
SmallChatNavFindClassesTest >> testFindClassesReturnsMatchingClasses [
	| result |
	result := SmallChatNav findClasses: 'LMSession'.
	self assert: (result includesSubstring: 'SmallChatLMSession').
	self assert: (result includesSubstring: '(SmallChat-LM)')
]

{ #category : 'tests' }
SmallChatNavFindClassesTest >> testFindClassesReturnsNoMatchesForUnknownPattern [
	| result |
	result := SmallChatNav findClasses: 'XyzNoSuchClassPattern'.
	self assert: (result includesSubstring: '_no matches_')
]

{ #category : 'tests' }
SmallChatNavFindClassesTest >> testFindClassesTruncatesWhenOverBudget [
	| result |
	SmallChatNavBudget default size: 200.
	result := SmallChatNav findClasses: '.'.
	self assert: (result includesSubstring: 'showing first')
]
