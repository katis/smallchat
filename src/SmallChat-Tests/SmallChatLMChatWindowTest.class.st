"
Tests for the chat window entry points.
"
Class {
	#name : 'SmallChatLMChatWindowTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'helpers' }
SmallChatLMChatWindowTest >> stubSessionWithCannedReply: aString [
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
SmallChatLMChatWindowTest >> testPresenterCachePreservesFoldStateAcrossSends [
    | window session firstAssistantPresenter |
    session := self stubSessionWithCannedReply: '<think>reasoning</think>hello'.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    window input text: 'hi'.
    window sendFromInput.
    window waitForPending.
    firstAssistantPresenter := window messagePresenters last.
    self assert: firstAssistantPresenter hasThinking.
    self deny: firstAssistantPresenter isThinkingVisible.
    firstAssistantPresenter toggleThinking.
    self assert: firstAssistantPresenter isThinkingVisible.
    window input text: 'again'.
    window sendFromInput.
    window waitForPending.
    self assert: window messagePresenters size equals: 4.
    self assert: (window messagePresenters at: 2) == firstAssistantPresenter.
    self assert: (window messagePresenters at: 2) isThinkingVisible
]

{ #category : 'tests' }
SmallChatLMChatWindowTest >> testSendFromInputAppendsPresenterForEachMessage [
    | window session |
    session := self stubSessionWithCannedReply: 'hello back'.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    window input text: 'hi'.
    window sendFromInput.
    window waitForPending.
    self assert: window messagePresenters size equals: 2.
    self assert: (window messagePresenters first message role) equals: #user.
    self assert: (window messagePresenters last message role) equals: #assistant
]

{ #category : 'tests' }
SmallChatLMChatWindowTest >> testSendFromInputReturnsImmediatelyWhilePendingReply [
    | stub client session window |
    stub := SmallChatLMHttpStub new
        response: (STONJSON toString: (Dictionary new
            at: 'choices' put: { Dictionary new
                at: 'message' put: (Dictionary new
                    at: 'role' put: 'assistant';
                    at: 'content' put: 'later';
                    yourself);
                yourself };
            yourself));
        gateOn;
        yourself.
    client := SmallChatLMChatClient new
        baseUrl: 'http://localhost:1234';
        httpClient: stub;
        yourself.
    session := SmallChatLMSession new
        client: client;
        yourself.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    window input text: 'hi'.
    window sendFromInput.
    self assert: window pendingRequest notNil description: 'fork should be in flight'.
    self assert: (window messagePresenters anySatisfy: [ :p | p message content = 'hi' ]).
    self assert: (window statusLabel label asLowercase includesSubstring: 'wait').
    self deny: window sendButton isEnabled.
    stub releaseGate.
    window waitForPending.
    self assert: window pendingRequest isNil description: 'pending cleared after reply'.
    self assert: (window messagePresenters anySatisfy: [ :p | p message content = 'later' ]).
    self assert: window statusLabel label isEmpty.
    self assert: window sendButton isEnabled
]

{ #category : 'tests' }
SmallChatLMChatWindowTest >> testSystemMessagesNotRendered [
	| window session |
	session := self stubSessionWithCannedReply: 'hello back'.
	window := SmallChatLMChatWindow new
		session: session;
		yourself.
	self assert: (session conversation messages anySatisfy: [ :m | m role = #system ])
		description: 'precondition: session has a seeded system turn'.
	self deny: (window messagePresenters anySatisfy: [ :p | p message role = #system ])
]

{ #category : 'tests' }
SmallChatLMChatWindowTest >> testWorldMenuItemOpensChatWindow [
	| method builder item |
	method := SmallChatLMChatWindow class >> #menuCommandOn:.
	self
		assert: (method pragmas anySatisfy: [ :p | p selector = #worldMenu ])
		description: 'menuCommandOn: must carry the <worldMenu> pragma so Pharo registers it'.
	builder := PragmaMenuBuilder pragmaKeyword: #worldMenu model: Object new.
	SmallChatLMChatWindow menuCommandOn: builder.
	self assert: builder itemList size equals: 1.
	item := builder itemList first.
	self
		assert: (item name asString asLowercase includesSubstring: 'smallchat')
		description: 'menu item label should identify smallchat'
]
