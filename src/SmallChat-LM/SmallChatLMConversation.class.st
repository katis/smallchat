"
Ordered list of SmallChatLMMessage. Convenience methods for appending
common roles. Input to prompt templates and clients.
"
Class {
	#name : 'SmallChatLMConversation',
	#superclass : 'Object',
	#instVars : [
		'messages'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'adding' }
SmallChatLMConversation >> addAssistant: aString [
	^ self addMessage: (SmallChatLMMessage role: #assistant content: aString)
]

{ #category : 'adding' }
SmallChatLMConversation >> addMessage: aMessage [
	messages add: aMessage.
	^ aMessage
]

{ #category : 'adding' }
SmallChatLMConversation >> addSystem: aString [
	^ self addMessage: (SmallChatLMMessage role: #system content: aString)
]

{ #category : 'adding' }
SmallChatLMConversation >> addUser: aString [
	^ self addMessage: (SmallChatLMMessage role: #user content: aString)
]

{ #category : 'initialization' }
SmallChatLMConversation >> initialize [
	super initialize.
	messages := OrderedCollection new
]

{ #category : 'accessing' }
SmallChatLMConversation >> messages [
	^ messages
]
