Class {
	#name : 'SmallChatNavDescribeClassTest',
	#superclass : 'TestCase',
	#instVars : [
		'savedBudget'
	],
	#category : 'SmallChat-NavTests',
	#package : 'SmallChat-NavTests'
}

{ #category : 'running' }
SmallChatNavDescribeClassTest >> setUp [
	super setUp.
	savedBudget := SmallChatNavBudget default size
]

{ #category : 'running' }
SmallChatNavDescribeClassTest >> tearDown [
	SmallChatNavBudget default size: savedBudget.
	super tearDown
]

{ #category : 'tests' }
SmallChatNavDescribeClassTest >> testDescribesKnownClass [
	| result |
	result := SmallChatNav describeClass: #SmallChatLMSession.
	self assert: (result includesSubstring: 'SmallChatLMSession').
	self assert: (result includesSubstring: 'SmallChat-LM')
]

{ #category : 'tests' }
SmallChatNavDescribeClassTest >> testIncludesInstanceVarsAndProtocolsAndKeySelectors [
	| result |
	result := SmallChatNav describeClass: #SmallChatLMSession.
	self assert: (result includesSubstring: '**Instance vars:**').
	self assert: (result includesSubstring: '**Public protocols:**').
	self assert: (result includesSubstring: '**Key selectors:**')
]

{ #category : 'tests' }
SmallChatNavDescribeClassTest >> testNotFoundReturnsLabel [
	| result |
	result := SmallChatNav describeClass: #ThisClassNameDoesNotExistAnywhere.
	self assert: (result includesSubstring: '_class not found:')
]
