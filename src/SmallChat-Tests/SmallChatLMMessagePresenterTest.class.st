Class {
	#name : 'SmallChatLMMessagePresenterTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMMessagePresenterTest >> testPresenterAcceptsToolActivityAndShowsToggleCollapsed [
	| msg presenter |
	msg := SmallChatLMMessage role: #assistant content: 'The answer is 7.'.
	presenter := SmallChatLMMessagePresenter on: msg.
	presenter toolActivity: 'evaluate(3+4) => 7'.
	self assert: presenter hasToolActivity.
	self deny: presenter isToolActivityVisible
]

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
SmallChatLMMessagePresenterTest >> testPresenterWithoutToolActivityOmitsToggle [
	| msg presenter |
	msg := SmallChatLMMessage role: #assistant content: 'plain'.
	presenter := SmallChatLMMessagePresenter on: msg.
	self deny: presenter hasToolActivity
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
SmallChatLMMessagePresenterTest >> testToggleGlyphsAreAscii [
	"Regression: Tonel round-trips multi-byte UTF-8 as mojibake.
	 Keep the glyphs in the 7-bit ASCII range so the label renders cleanly."
	self assert: (SmallChatLMMessagePresenter collapsedGlyph allSatisfy: [ :c | c asInteger < 128 ]).
	self assert: (SmallChatLMMessagePresenter expandedGlyph allSatisfy: [ :c | c asInteger < 128 ])
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

{ #category : 'tests' }
SmallChatLMMessagePresenterTest >> testToggleToolActivityFlipsVisibility [
	| msg presenter |
	msg := SmallChatLMMessage role: #assistant content: 'done'.
	presenter := SmallChatLMMessagePresenter on: msg.
	presenter toolActivity: 'evaluate(x) => y'.
	presenter toggleToolActivity.
	self assert: presenter isToolActivityVisible.
	presenter toggleToolActivity.
	self deny: presenter isToolActivityVisible
]
