"
Abstract provider seam. A client takes a SmallChatLMConversation and
returns the next assistant SmallChatLMMessage. Subclasses differ in
transport and wire format, not in caller-facing shape.

Today: SmallChatLMCompletionsClient (LM Studio /v1/completions + in-image
template). Future: SmallChatLMChatClient (/v1/chat/completions where the
server renders the template), SmallChatLMAnthropicClient (Messages API),
etc. The tool-call loop, when it lands, will live one layer up on
SmallChatLMSession and call #complete: in a loop.
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
