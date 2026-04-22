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
			at: 'choices' put: { Dictionary new
				at: 'message' put: (Dictionary new
					at: 'role' put: 'assistant';
					at: 'content' put: aString;
					yourself);
				yourself };
			yourself));
		yourself.
	client := SmallChatLMChatClient new
		baseUrl: 'http://localhost:1234';
		httpClient: stub;
		yourself.
	session := SmallChatLMSession new
		client: client;
		yourself.
	^ session
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testConversationSeededWithConfigSystemPrompt [
	| session first |
	session := SmallChatLMSession new.
	first := session conversation messages first.
	self assert: first role equals: #system.
	self assert: first content equals: SmallChatConfig systemPrompt
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testEmptyInputIsANoOp [
	| session before |
	session := self sessionWithCannedReply: 'ignored'.
	before := session conversation messages size.
	self assert: (session sendUserInput: '') isNil.
	self assert: session conversation messages size equals: before.
	self deny: (session conversation messages anySatisfy: [ :m | m role = #user or: [ m role = #assistant ] ])
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testSendUserInputAppendsUserAndAssistantTurns [
	| session reply nonSystemRoles |
	session := self sessionWithCannedReply: 'hello back'.
	reply := session sendUserInput: 'hi'.
	self assert: reply role equals: #assistant.
	self assert: reply content equals: 'hello back'.
	nonSystemRoles := (session conversation messages reject: [ :m | m role = #system ])
		collect: [ :m | m role ].
	self assert: nonSystemRoles asArray equals: #(#user #assistant)
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testSessionInitializesWithChatClient [
	self assert: SmallChatLMSession new client class equals: SmallChatLMChatClient
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testTranscriptTextIncludesBothTurns [
	| session |
	session := self sessionWithCannedReply: 'hello back'.
	session sendUserInput: 'hi'.
	self assert: (session transcriptText includesSubstring: 'user: hi').
	self assert: (session transcriptText includesSubstring: 'assistant: hello back')
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testTranscriptTextOmitsThinking [
	| session text |
	session := self sessionWithCannedReply: '<think>reasoning</think>hello back'.
	session sendUserInput: 'hi'.
	text := session transcriptText.
	self assert: (text includesSubstring: 'assistant: hello back').
	self deny: (text includesSubstring: 'reasoning')
]
