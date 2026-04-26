Class {
	#name : 'SmallChatNavFindMethodsTest',
	#superclass : 'TestCase',
	#instVars : [
		'savedBudget'
	],
	#category : 'SmallChat-NavTests',
	#package : 'SmallChat-NavTests'
}

{ #category : 'running' }
SmallChatNavFindMethodsTest >> setUp [
	super setUp.
	savedBudget := SmallChatNavBudget default size
]

{ #category : 'running' }
SmallChatNavFindMethodsTest >> tearDown [
	SmallChatNavBudget default size: savedBudget.
	super tearDown
]

{ #category : 'tests' }
SmallChatNavFindMethodsTest >> testFindMethodsCapsAt50 [
	| result |
	"Object has hundreds of selectors; cap should kick in."
	result := SmallChatNav findMethods: '.' in: #Object.
	self assert: (result includesSubstring: 'showing first 50')
]

{ #category : 'tests' }
SmallChatNavFindMethodsTest >> testFindMethodsMatchesClassSideSelectors [
	"Class-side methods (e.g. SmallChatNav class>>describeClass:) must be
	 reachable through findMethods: -- otherwise the agent can't discover
	 SmallChatTsNav's API in two hops."
	| result |
	result := SmallChatNav findMethods: 'describeClass' in: #SmallChatNav.
	self assert: (result includesSubstring: 'class>>describeClass:')
]

{ #category : 'tests' }
SmallChatNavFindMethodsTest >> testFindMethodsReturnsMatchingSelectors [
	| result |
	result := SmallChatNav findMethods: 'send' in: #SmallChatLMSession.
	self assert: (result includesSubstring: 'sendUserInput:').
	self assert: (result includesSubstring: 'SmallChatLMSession>>')
]

{ #category : 'tests' }
SmallChatNavFindMethodsTest >> testFindMethodsReturnsNoMatches [
	| result |
	result := SmallChatNav findMethods: 'thisSelectorDoesNotExist' in: #SmallChatLMSession.
	self assert: (result includesSubstring: '_no matches_')
]
