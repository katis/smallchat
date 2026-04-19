"
Abstract in-image prompt template. Turns a SmallChatLMConversation into a
string ready for /v1/completions and declares the stop tokens the client
should pass to the server.

Two seams live here deliberately:
  #render:     the model's chat format (special tokens, turn markers)
  #stopTokens  what terminates a generation for that format

Keeping this layer in-image is what lets us later inject tool-call schemas
or reasoning-mode tags per model without fighting a server-side template.
"
Class {
	#name : 'SmallChatLMPromptTemplate',
	#superclass : 'Object',
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'rendering' }
SmallChatLMPromptTemplate >> render: aConversation [
	^ self subclassResponsibility
]

{ #category : 'accessing' }
SmallChatLMPromptTemplate >> stopTokens [
	^ self subclassResponsibility
]
