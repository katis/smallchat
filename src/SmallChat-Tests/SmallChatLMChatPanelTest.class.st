Class {
	#name : 'SmallChatLMChatPanelTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testInitializeBuildsAllPresenters [
  | panel |
  panel := SmallChatLMChatPanel new.
  self assert: panel input notNil.
  self assert: panel sendButton notNil.
  self assert: panel messagesPane notNil.
  self assert: panel statusLabel notNil.
  self assert: panel mcpStatusLabel notNil
]
