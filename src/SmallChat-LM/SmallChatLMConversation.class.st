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
SmallChatLMConversation >> addTool: aString forCallId: anId [
	^ self addMessage: (SmallChatLMMessage role: #tool content: aString toolCallId: anId)
]

{ #category : 'adding' }
SmallChatLMConversation >> addUser: aString [
	^ self addMessage: (SmallChatLMMessage role: #user content: aString)
]

{ #category : 'copying' }
SmallChatLMConversation >> copy [
    "Independent copy: messages collection is its own, but message instances are
     shared (intentional -- tests rely on identity for the presenter cache)."
    ^ self class new
        copyMessagesFrom: messages;
        yourself
]

{ #category : 'copying' }
SmallChatLMConversation >> copyMessagesFrom: aCollection [
    "asOrderedCollection on an OrderedCollection returns self -- copy explicitly."
    messages := aCollection asOrderedCollection copy
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

{ #category : 'adding' }
SmallChatLMConversation >> removeMessage: aMessage [
    "Drop aMessage if present. Used by the chat window when a streaming send fails
     before any chunk arrives so an empty assistant placeholder doesn't linger."
    messages remove: aMessage ifAbsent: [ ]
]
