"
Abstract provider seam. A client takes a SmallChatLMConversation and
returns the next assistant SmallChatLMMessage. Subclasses differ in
transport and wire format, not in caller-facing shape.

Today: SmallChatLMChatClient (OpenAI-style /v1/chat/completions; target
server is a local oMLX). The tool-call loop, when it lands, will live
one layer up on SmallChatLMSession and call #complete: in a loop.
"
Class {
	#name : 'SmallChatLMClient',
	#superclass : 'Object',
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'chat' }
SmallChatLMClient >> complete: aConversation [
	^ self subclassResponsibility
]
