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
SmallChatLMChatWindowTest >> deltaChunkWithContent: aString [
    "Mirror SmallChatLMChatClientTest>>deltaChunkWithContent: -- streaming-shaped
     frame whose delta carries aString as content."
    | delta choice |
    delta := Dictionary new at: 'content' put: aString; yourself.
    choice := Dictionary new at: 'delta' put: delta; yourself.
    ^ Dictionary new at: 'choices' put: { choice }; yourself
]

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

{ #category : 'helpers' }
SmallChatLMChatWindowTest >> stubSessionWithChunks: anArray [
    "Build a session with a stub whose post:to:withHeaders:onChunk: emits anArray
     in order. anArray elements are streaming-shaped frame dicts (see
     SmallChatLMChatClientTest>>deltaChunkWithContent:)."
    | stub client session |
    stub := SmallChatLMHttpStub new
        chunks: anArray;
        yourself.
    client := SmallChatLMChatClient new
        baseUrl: 'http://localhost:1234';
        httpClient: stub;
        yourself.
    session := SmallChatLMSession new
        client: client;
        yourself.
    ^ { session . stub }
]

{ #category : 'tests' }
SmallChatLMChatWindowTest >> testErrorFromClientShowsErrorInStatusLabel [
    | stub client session window assistantTurns |
    stub := SmallChatLMHttpStub new
        raiseOnPost: 'boom';
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
    window waitForPending.
    self assert: (window statusLabel label asLowercase includesSubstring: 'error').
    self assert: (window statusLabel label includesSubstring: 'boom').
    self assert: window pendingRequest isNil.
    self assert: window sendButton isEnabled.
    assistantTurns := session conversation messages select: [ :m | m role = #assistant ].
    self assert: assistantTurns isEmpty
]

{ #category : 'tests-streaming' }
SmallChatLMChatWindowTest >> testMessagesPaneIsScrollable [
    "The transcript needs to scroll vertically when long replies push it past
     the window height."
    | session window |
    session := self stubSessionWithCannedReply: 'hello'.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    self assert: window messagesPane layout class equals: SpScrollableLayout.
    window input text: 'hi'.
    window sendFromInput.
    window waitForPending.
    self assert: window messagesPane layout class equals: SpScrollableLayout
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
SmallChatLMChatWindowTest >> testSecondSendBlockedWhileFirstPending [
    | stub client session window userTurns |
    stub := SmallChatLMHttpStub new
        response: (STONJSON toString: (Dictionary new
            at: 'choices' put: { Dictionary new
                at: 'message' put: (Dictionary new
                    at: 'role' put: 'assistant';
                    at: 'content' put: 'ok';
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
    window input text: 'one'.
    window sendFromInput.
    window input text: 'two'.
    window sendFromInput.
    userTurns := session conversation messages select: [ :m | m role = #user ].
    self assert: userTurns size equals: 1.
    self assert: userTurns first content equals: 'one'.
    self deny: window sendButton isEnabled.
    stub releaseGate.
    window waitForPending.
    self assert: window sendButton isEnabled.
    window input text: 'two'.
    window sendFromInput.
    userTurns := session conversation messages select: [ :m | m role = #user ].
    self assert: userTurns size equals: 2.
    self assert: userTurns second content equals: 'two'.
    stub releaseGate.
    window waitForPending
]

{ #category : 'tests' }
SmallChatLMChatWindowTest >> testSendAfterErrorIsAccepted [
    | stub client session window userTurns |
    stub := SmallChatLMHttpStub new
        raiseOnPost: 'first failure';
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
    window input text: 'one'.
    window sendFromInput.
    window waitForPending.
    self assert: window pendingRequest isNil.
    self assert: window sendButton isEnabled.
    "Swap stub back to a canned reply for the follow-up send."
    stub
        raiseOnPost: nil;
        response: (STONJSON toString: (Dictionary new
            at: 'choices' put: { Dictionary new
                at: 'message' put: (Dictionary new
                    at: 'role' put: 'assistant';
                    at: 'content' put: 'ok';
                    yourself);
                yourself };
            yourself)).
    window input text: 'two'.
    window sendFromInput.
    window waitForPending.
    userTurns := session conversation messages select: [ :m | m role = #user ].
    self assert: userTurns size equals: 2.
    self assert: (session conversation messages anySatisfy: [ :m |
        m role = #assistant and: [ m content = 'ok' ] ])
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

{ #category : 'tests-streaming' }
SmallChatLMChatWindowTest >> testStreamingClearsStatusOnDone [
    | pair session window |
    pair := self stubSessionWithChunks: { self deltaChunkWithContent: 'hi' }.
    session := pair first.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    window input text: 'hi'.
    window sendFromInput.
    window waitForPending.
    self assert: window statusLabel label isEmpty.
    self assert: window sendButton isEnabled.
    self assert: window pendingRequest isNil
]

{ #category : 'tests-streaming' }
SmallChatLMChatWindowTest >> testStreamingDeltasGrowAssistantContent [
    | pair session window assistantTurns |
    pair := self stubSessionWithChunks: {
        self deltaChunkWithContent: 'a'.
        self deltaChunkWithContent: 'b'.
        self deltaChunkWithContent: 'c' }.
    session := pair first.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    window input text: 'hi'.
    window sendFromInput.
    window waitForPending.
    assistantTurns := session conversation messages select: [ :m | m role = #assistant ].
    self assert: assistantTurns size equals: 1.
    self assert: assistantTurns first content equals: 'abc'
]

{ #category : 'tests-streaming' }
SmallChatLMChatWindowTest >> testStreamingDoesNotDuplicateAssistantTurn [
    "Regression: the placeholder mutation pattern means the streaming finalise
     must reconcile into the placeholder, not addMessage: a new assistant turn."
    | pair session window assistantTurns |
    pair := self stubSessionWithChunks: {
        self deltaChunkWithContent: 'hi'.
        self deltaChunkWithContent: ' there' }.
    session := pair first.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    window input text: 'hi'.
    window sendFromInput.
    window waitForPending.
    assistantTurns := session conversation messages select: [ :m | m role = #assistant ].
    self assert: assistantTurns size equals: 1.
    self assert: assistantTurns first content equals: 'hi there'
]

{ #category : 'tests-streaming' }
SmallChatLMChatWindowTest >> testStreamingMidStreamErrorPreservesPartialAssistantContent [
    "Two chunks land, then the stream raises. The partial assistant content
     ('ab') must remain in the transcript -- the placeholder is not removed
     -- and the status label/send button reflect the failure."
    | pair session stub window assistantTurns |
    pair := self stubSessionWithChunks: {
        self deltaChunkWithContent: 'a'.
        self deltaChunkWithContent: 'b' }.
    session := pair first.
    stub := pair second.
    stub raiseOnPost: 'mid-stream boom'.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    window input text: 'hi'.
    window sendFromInput.
    window waitForPending.
    self assert: window pendingRequest isNil.
    self assert: window sendButton isEnabled.
    self assert: (window statusLabel label asLowercase includesSubstring: 'error').
    self assert: (window statusLabel label includesSubstring: 'mid-stream boom').
    assistantTurns := session conversation messages select: [ :m | m role = #assistant ].
    self assert: assistantTurns size equals: 1.
    self assert: assistantTurns first content equals: 'ab'
]

{ #category : 'tests-streaming' }
SmallChatLMChatWindowTest >> testStreamingPlaceholderAssistantBubbleAppearsBeforeFirstChunk [
    | pair session stub window assistantTurns |
    pair := self stubSessionWithChunks: { self deltaChunkWithContent: 'hi' }.
    session := pair first.
    stub := pair second.
    stub gateOn.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    window input text: 'hello'.
    window sendFromInput.
    "Before releasing the gate, the user message and the empty assistant
     placeholder should both be rendered."
    self assert: window messagePresenters size equals: 2.
    assistantTurns := session conversation messages select: [ :m | m role = #assistant ].
    self assert: assistantTurns size equals: 1.
    self assert: assistantTurns first content equals: ''.
    stub releaseGate.
    window waitForPending
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
