Class {
	#name : 'SmallChatLMSessionTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'helpers' }
SmallChatLMSessionTest >> sessionWithCannedReply: aString [
	| stub client session |
	stub := SmallChatLMHttpStub new
		response: (STONJSON toString: (Dictionary new
			at: 'choices' put: { Dictionary new at: 'text' put: aString; yourself };
			yourself));
		yourself.
	client := SmallChatLMCompletionsClient new
		baseUrl: 'http://localhost:1234';
		httpClient: stub;
		yourself.
	session := SmallChatLMSession new
		client: client;
		yourself.
	^ session
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testEmptyInputIsANoOp [
	| session |
	session := self sessionWithCannedReply: 'ignored'.
	self assert: (session sendUserInput: '') isNil.
	self assert: session conversation messages isEmpty
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testSendUserInputAppendsUserAndAssistantTurns [
	| session reply roles |
	session := self sessionWithCannedReply: 'hello back<|im_end|>'.
	reply := session sendUserInput: 'hi'.
	self assert: reply role equals: #assistant.
	self assert: reply content equals: 'hello back'.
	roles := (session conversation messages collect: [ :m | m role ]) asArray.
	self assert: roles equals: #(#user #assistant)
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testTranscriptTextIncludesBothTurns [
	| session |
	session := self sessionWithCannedReply: 'hello back<|im_end|>'.
	session sendUserInput: 'hi'.
	self assert: (session transcriptText includesSubstring: 'user: hi').
	self assert: (session transcriptText includesSubstring: 'assistant: hello back')
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testTranscriptTextOmitsThinking [
	| session text |
	session := self sessionWithCannedReply: '<think>reasoning</think>hello back<|im_end|>'.
	session sendUserInput: 'hi'.
	text := session transcriptText.
	self assert: (text includesSubstring: 'assistant: hello back').
	self deny: (text includesSubstring: 'reasoning')
]
