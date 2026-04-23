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
SmallChatLMChatWindowTest >> testDefaultLayoutPlacesMcpHeaderAtTop [
    "MCP status sits at the very top of the window, above the transcript."
    | window |
    window := SmallChatLMChatWindow new.
    self assert: window defaultLayout children first == window mcpStatusLabel
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

{ #category : 'tests' }
SmallChatLMChatWindowTest >> testLabelForMCPState [
    "Pure mapping from SmallChatMCPStateChanged to label text. ASCII only --
     Tonel round-trips non-ASCII as mojibake in Pharo 13."
    | off listening connected |
    off := SmallChatMCPStateChanged new running: false; clientCount: 0; yourself.
    listening := SmallChatMCPStateChanged new running: true; clientCount: 0; yourself.
    connected := SmallChatMCPStateChanged new running: true; clientCount: 1; yourself.
    self assert: (SmallChatLMChatWindow labelForMCPState: off) equals: 'MCP: offline'.
    self assert: (SmallChatLMChatWindow labelForMCPState: listening) equals: 'MCP: listening'.
    self assert: (SmallChatLMChatWindow labelForMCPState: connected) equals: 'MCP: connected'
]

{ #category : 'tests' }
SmallChatLMChatWindowTest >> testMcpStatusLabelPresentAndInitialised [
    | window |
    window := SmallChatLMChatWindow new.
    self assert: window mcpStatusLabel notNil.
    self assert: (window mcpStatusLabel label beginsWith: 'MCP: ')
]

{ #category : 'tests-streaming' }
SmallChatLMChatWindowTest >> testMessageBubbleGrowsToFitContent [
    "Each bubble's content widget propagates its natural height upward so the
     parent layout sizes the bubble to the text. Without this, multi-line
     replies clip into the small default text-widget height."
    | session window contentText |
    session := self stubSessionWithCannedReply: 'line one
line two
line three'.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    window input text: 'hi'.
    window sendFromInput.
    window waitForPending.
    contentText := window messagePresenters last contentText.
    self assert: contentText isPropagateNaturalHeight
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

{ #category : 'tests-streaming' }
SmallChatLMChatWindowTest >> testStreamingThinkingAppearingMidStreamDoesNotRaise [
    "When </think> closes mid-stream the cached presenter must instantiate
     the thinking widgets and re-apply its layout. The previous
     buildWithSpec rebuild path raised a DNU that opened Pharo's UI
     debugger in the live window."
    | pair session window placeholder presenter |
    pair := self stubSessionWithChunks: {
        self deltaChunkWithContent: '<think>'.
        self deltaChunkWithContent: 'reason</think>final' }.
    session := pair first.
    window := SmallChatLMChatWindow new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    window input text: 'hi'.
    window sendFromInput.
    window waitForPending.
    placeholder := session conversation messages last.
    presenter := window messagePresenters last.
    self assert: placeholder content equals: 'final'.
    self assert: placeholder thinking equals: 'reason'.
    self assert: presenter hasThinking
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
SmallChatLMChatWindowTest >> testTranscriptFiltersIntermediateToolPlumbing [
	"After a tool-calling round, the conversation contains user / asst(tool_calls) /
	 tool(result) / asst(final). The transcript should only show user and the
	 final assistant bubble -- intermediate tool-call-only assistant messages and
	 #tool messages are not standalone bubbles."
	| session window tc plumbingMsg toolMsg finalMsg |
	session := self stubSessionWithCannedReply: 'unused'.
	window := SmallChatLMChatWindow new
		session: session;
		uiDeferrer: [ :blk | blk value ];
		yourself.
	"Hand-build a post-tool-round conversation state."
	session conversation addUser: 'what is 3+4?'.
	tc := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{"code":"3+4"}'.
	plumbingMsg := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
	session conversation addMessage: plumbingMsg.
	toolMsg := SmallChatLMMessage role: #tool content: '7' toolCallId: 'c1'.
	session conversation addMessage: toolMsg.
	finalMsg := SmallChatLMMessage role: #assistant content: 'The answer is 7.'.
	session conversation addMessage: finalMsg.
	window refreshMessages.
	self assert: window messagePresenters size equals: 2.
	self assert: (window messagePresenters first message role) equals: #user.
	self assert: (window messagePresenters second message) equals: finalMsg
]

{ #category : 'tests' }
SmallChatLMChatWindowTest >> testUnsubscribeFromMCPAnnouncerStopsUpdates [
    "After unsubscribeFromMCPAnnouncer, further announcements on the default
     TCP server's announcer must NOT update the window's label. This is what
     initializeWindow: wires into whenClosedDo: so closed windows don't leak
     subscriptions or mutate disposed widgets."
    | window announcer before |
    window := SmallChatLMChatWindow new
        uiDeferrer: [ :blk | blk value ];
        yourself.
    announcer := SmallChatMCPTcpServer default announcer.
    before := window mcpStatusLabel label.
    [
        window unsubscribeFromMCPAnnouncer.
        announcer announce:
            (SmallChatMCPStateChanged new
                running: true;
                clientCount: 99;
                yourself).
        self assert: window mcpStatusLabel label equals: before
    ] ensure: [ announcer unsubscribe: window ]
]

{ #category : 'tests' }
SmallChatLMChatWindowTest >> testWindowUpdatesLabelOnMCPStateAnnouncement [
    "Announce a synthetic state change through the default TCP server's
     announcer; the window should have subscribed during #initializePresenters
     and must update mcpStatusLabel accordingly. Cleanup unsubscribes the
     window from the (real, live) default announcer."
    | window announcer |
    window := SmallChatLMChatWindow new
        uiDeferrer: [ :blk | blk value ];
        yourself.
    announcer := SmallChatMCPTcpServer default announcer.
    [
        announcer announce:
            (SmallChatMCPStateChanged new
                running: true;
                clientCount: 2;
                yourself).
        self assert: window mcpStatusLabel label equals: 'MCP: connected'.
        announcer announce:
            (SmallChatMCPStateChanged new
                running: true;
                clientCount: 0;
                yourself).
        self assert: window mcpStatusLabel label equals: 'MCP: listening'.
        announcer announce:
            (SmallChatMCPStateChanged new
                running: false;
                clientCount: 0;
                yourself).
        self assert: window mcpStatusLabel label equals: 'MCP: offline'
    ] ensure: [ announcer unsubscribe: window ]
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
