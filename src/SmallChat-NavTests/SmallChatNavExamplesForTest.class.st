Class {
	#name : 'SmallChatNavExamplesForTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-NavTests',
	#package : 'SmallChat-NavTests'
}

{ #category : 'tests' }
SmallChatNavExamplesForTest >> testFallsBackToSiblingTestClass [
	| result |
	result := SmallChatNav examplesFor: #SmallChatLMSession.
	self assert: (result includesSubstring: 'SmallChatLMSessionTest')
]

{ #category : 'tests' }
SmallChatNavExamplesForTest >> testNoExamplesNoSibling [
	"SmallChatNavBudget has no examples protocol and no SmallChatNavBudgetTest sibling."
	| result |
	result := SmallChatNav examplesFor: #SmallChatNavBudget.
	self assert: (result includesSubstring: '_No examples yet')
]

{ #category : 'tests' }
SmallChatNavExamplesForTest >> testRendersExamplesProtocol [
	| result |
	result := SmallChatNav examplesFor: #SmallChatNavExampleFixture.
	self assert: (result includesSubstring: 'demoExample').
	self assert: (result includesSubstring: '```smalltalk')
]
