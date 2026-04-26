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
SmallChatNavDescribeClassTest >> testGroupsInstanceSelectorsByProtocol [
	"Instance-side classes render selectors grouped under their public
	 protocols so the agent can see what's available without a second
	 findMethods: call. Selectors appear inline, prefixed by the bullet."
	| result |
	result := SmallChatNav describeClass: #SmallChatLMSession.
	self assert: (result includesSubstring: '**Instance-side selectors**').
	self assert: (result includesSubstring: 'sendUserInput:')
]

{ #category : 'tests' }
SmallChatNavDescribeClassTest >> testIncludesInstanceVars [
	| result |
	result := SmallChatNav describeClass: #SmallChatLMSession.
	self assert: (result includesSubstring: '**Instance vars:**')
]

{ #category : 'tests' }
SmallChatNavDescribeClassTest >> testNotFoundReturnsLabel [
	| result |
	result := SmallChatNav describeClass: #ThisClassNameDoesNotExistAnywhere.
	self assert: (result includesSubstring: '_class not found:')
]

{ #category : 'tests' }
SmallChatNavDescribeClassTest >> testSurfacesClassSideSelectors [
	"SmallChatTsNav is fully class-side; describeClass: must show its
	 class-side public surface so the agent can discover findFiles:,
	 renameSymbolAt:line:character:to:, etc. without a second hop."
	| result |
	result := SmallChatNav describeClass: #SmallChatNav.
	self assert: (result includesSubstring: '**Class-side selectors**').
	self assert: (result includesSubstring: 'findClasses:').
	self assert: (result includesSubstring: 'describeClass:')
]
