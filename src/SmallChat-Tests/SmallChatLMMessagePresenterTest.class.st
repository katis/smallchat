Class {
	#name : 'SmallChatLMMessagePresenterTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMMessagePresenterTest >> testPresenterForMessageWithThinkingStartsCollapsed [
	| msg presenter |
	msg := SmallChatLMMessage role: #assistant content: 'hi' thinking: 'reasoning'.
	presenter := SmallChatLMMessagePresenter on: msg.
	self assert: presenter hasThinking.
	self deny: presenter isThinkingVisible
]

{ #category : 'tests' }
SmallChatLMMessagePresenterTest >> testPresenterForMessageWithoutThinkingOmitsToggle [
	| msg presenter |
	msg := SmallChatLMMessage role: #assistant content: 'hi'.
	presenter := SmallChatLMMessagePresenter on: msg.
	self deny: presenter hasThinking
]

{ #category : 'tests' }
SmallChatLMMessagePresenterTest >> testToggleExpandsAndCollapses [
	| msg presenter |
	msg := SmallChatLMMessage role: #assistant content: 'hi' thinking: 'reasoning'.
	presenter := SmallChatLMMessagePresenter on: msg.
	presenter toggleThinking.
	self assert: presenter isThinkingVisible.
	presenter toggleThinking.
	self deny: presenter isThinkingVisible
]

{ #category : 'tests' }
SmallChatLMMessagePresenterTest >> testToggleLabelReflectsState [
	| msg presenter |
	msg := SmallChatLMMessage role: #assistant content: 'hi' thinking: 'reasoning'.
	presenter := SmallChatLMMessagePresenter on: msg.
	self assert: (presenter toggleLabel includesSubstring: SmallChatLMMessagePresenter collapsedGlyph).
	presenter toggleThinking.
	self assert: (presenter toggleLabel includesSubstring: SmallChatLMMessagePresenter expandedGlyph)
]
