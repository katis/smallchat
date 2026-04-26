Class {
	#name : 'SmallChatLMChatPanelTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'helpers' }
SmallChatLMChatPanelTest >> deltaChunkWithContent: aString [
    "Mirror SmallChatLMChatClientTest>>deltaChunkWithContent: -- streaming-shaped
     frame whose delta carries aString as content."
    | delta choice |
    delta := Dictionary new at: 'content' put: aString; yourself.
    choice := Dictionary new at: 'delta' put: delta; yourself.
    ^ Dictionary new at: 'choices' put: { choice }; yourself
]

{ #category : 'helpers' }
SmallChatLMChatPanelTest >> stubSessionWithCannedReply: aString [
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
SmallChatLMChatPanelTest >> stubSessionWithChunks: anArray [
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
SmallChatLMChatPanelTest >> testAssistantWithOnlyThinkingIsVisible [
    "Problem 1 regression: an assistant turn whose only output is a thinking
     block must produce a visible #thinking section rather than vanishing
     from the transcript entirely."
    | session panel msg secs |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    msg := SmallChatLMMessage role: #assistant content: '' thinking: 'only reasoning, no answer yet'.
    session conversation addMessage: msg.
    secs := panel sections.
    self assert: (secs anySatisfy: [ :s | s kind = #thinking and: [ s message == msg ] ])
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testChatPanelHasNoMCPSurface [
    "After moving MCP observability to a dedicated console window, the chat
     panel must not expose MCP state or subscribe to the MCP announcer.
     Regression guard so the surface does not grow back."
    | panel |
    panel := SmallChatLMChatPanel new.
    self deny: (panel respondsTo: #mcpStatusLabel).
    self deny: (panel respondsTo: #applyMCPState:).
    self deny: (panel respondsTo: #subscribeToMCPAnnouncer).
    self deny: (panel respondsTo: #unsubscribeFromMCPAnnouncer).
    self deny: (SmallChatLMChatPanel class canUnderstand: #labelForMCPState:).
    self deny: (SmallChatLMChatPanel instVarNames includes: 'mcpStatusLabel')
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testErrorFromClientShowsErrorInStatusLabel [
    | stub client session panel assistantTurns |
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
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    self assert: (panel statusLabel label asLowercase includesSubstring: 'error').
    self assert: (panel statusLabel label includesSubstring: 'boom').
    self assert: panel pendingRequest isNil.
    self assert: panel sendButton isEnabled.
    assistantTurns := session conversation messages select: [ :m | m role = #assistant ].
    self assert: assistantTurns isEmpty
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testFinalAssistantBubblePresentsPrecedingToolActivity [
	"After refreshMessages, the presenter for the final content-bearing assistant
	 message carries a tool-activity summary derived from the preceding tool_calls
	 + tool-result messages."
	| session panel tc plumbingMsg toolMsg finalMsg finalPresenter |
	session := self stubSessionWithCannedReply: 'unused'.
	panel := SmallChatLMChatPanel new
		session: session;
		uiDeferrer: [ :blk | blk value ];
		yourself.
	session conversation addUser: 'what is 3+4?'.
	tc := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{"code":"3+4"}'.
	plumbingMsg := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
	session conversation addMessage: plumbingMsg.
	toolMsg := SmallChatLMMessage role: #tool content: '7' toolCallId: 'c1'.
	session conversation addMessage: toolMsg.
	finalMsg := SmallChatLMMessage role: #assistant content: 'The answer is 7.'.
	session conversation addMessage: finalMsg.
	panel refreshMessages.
	finalPresenter := panel messagePresenters last.
	self assert: finalPresenter hasToolActivity.
	self assert: (finalPresenter toolActivity includesSubstring: 'evaluate').
	self assert: (finalPresenter toolActivity includesSubstring: '7')
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testInitializeBuildsAllPresenters [
  | panel |
  panel := SmallChatLMChatPanel new.
  self assert: panel input notNil.
  self assert: panel sendButton notNil.
  self assert: panel messagesPane notNil.
  self assert: panel statusLabel notNil
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testMessageBubbleGrowsToFitContent [
    "Each bubble's content widget propagates its natural height upward so the
     parent layout sizes the bubble to the text. Without this, multi-line
     replies clip into the small default text-widget height."
    | session panel contentText |
    session := self stubSessionWithCannedReply: 'line one
line two
line three'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    contentText := panel messagePresenters last contentText.
    self assert: contentText isPropagateNaturalHeight
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testMessagesPaneIsScrollable [
    "The transcript needs to scroll vertically when long replies push it past
     the panel height."
    | session panel |
    session := self stubSessionWithCannedReply: 'hello'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    self assert: panel messagesPane layout class equals: SpScrollableLayout.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    self assert: panel messagesPane layout class equals: SpScrollableLayout
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testPresenterCachePreservesFoldStateAcrossSends [
    | panel session firstAssistantPresenter |
    session := self stubSessionWithCannedReply: '<think>reasoning</think>hello'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    firstAssistantPresenter := panel messagePresenters last.
    self assert: firstAssistantPresenter hasThinking.
    self deny: firstAssistantPresenter isThinkingVisible.
    firstAssistantPresenter toggleThinking.
    self assert: firstAssistantPresenter isThinkingVisible.
    panel input text: 'again'.
    panel sendFromInput.
    panel waitForPending.
    self assert: panel messagePresenters size equals: 4.
    self assert: (panel messagePresenters at: 2) == firstAssistantPresenter.
    self assert: (panel messagePresenters at: 2) isThinkingVisible
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSecondSendBlockedWhileFirstPending [
    | stub client session panel userTurns |
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
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'one'.
    panel sendFromInput.
    panel input text: 'two'.
    panel sendFromInput.
    userTurns := session conversation messages select: [ :m | m role = #user ].
    self assert: userTurns size equals: 1.
    self assert: userTurns first content equals: 'one'.
    self deny: panel sendButton isEnabled.
    stub releaseGate.
    panel waitForPending.
    self assert: panel sendButton isEnabled.
    panel input text: 'two'.
    panel sendFromInput.
    userTurns := session conversation messages select: [ :m | m role = #user ].
    self assert: userTurns size equals: 2.
    self assert: userTurns second content equals: 'two'.
    stub releaseGate.
    panel waitForPending
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSectionsExcludesSystemMessage [
    | session panel |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    self assert: (session conversation messages anySatisfy: [ :m | m role = #system ])
        description: 'precondition: session seeds a system message'.
    self assert: panel sections isEmpty
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSectionsForFullConversationInArrivalOrder [
    | session panel tc plumbingMsg toolMsg finalMsg secs |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    session conversation addUser: 'what is 3+4?'.
    tc := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{"code":"3+4"}'.
    plumbingMsg := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
    session conversation addMessage: plumbingMsg.
    toolMsg := SmallChatLMMessage role: #tool content: '7' toolCallId: 'c1'.
    session conversation addMessage: toolMsg.
    finalMsg := SmallChatLMMessage role: #assistant content: 'The answer is 7.'.
    finalMsg thinking: 'reasoning about arithmetic'.
    session conversation addMessage: finalMsg.
    secs := panel sections.
    self assert: (secs collect: [ :s | s kind ]) asArray
        equals: #( #user #toolCall #thinking #assistant ).
    self assert: (secs at: 1) message content equals: 'what is 3+4?'.
    self assert: (secs at: 2) toolCall == tc.
    self assert: (secs at: 2) toolResult equals: '7'.
    self assert: (secs at: 3) message == finalMsg.
    self assert: (secs at: 4) message == finalMsg
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSelectingUserSectionShowsContentAndEmptyOutput [
    | session panel userSec |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    session conversation addUser: 'hello world'.
    userSec := panel sections first.
    panel selectSection: userSec.
    self assert: panel contentText text asString equals: 'hello world'.
    self assert: panel outputText text asString isEmpty
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSendAfterErrorIsAccepted [
    | stub client session panel userTurns |
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
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'one'.
    panel sendFromInput.
    panel waitForPending.
    self assert: panel pendingRequest isNil.
    self assert: panel sendButton isEnabled.
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
    panel input text: 'two'.
    panel sendFromInput.
    panel waitForPending.
    userTurns := session conversation messages select: [ :m | m role = #user ].
    self assert: userTurns size equals: 2.
    self assert: (session conversation messages anySatisfy: [ :m |
        m role = #assistant and: [ m content = 'ok' ] ])
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSendFromInputAppendsPresenterForEachMessage [
    | panel session |
    session := self stubSessionWithCannedReply: 'hello back'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    self assert: panel messagePresenters size equals: 2.
    self assert: (panel messagePresenters first message role) equals: #user.
    self assert: (panel messagePresenters last message role) equals: #assistant
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSendFromInputReturnsImmediatelyWhilePendingReply [
    | stub client session panel |
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
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    self assert: panel pendingRequest notNil description: 'fork should be in flight'.
    self assert: (panel messagePresenters anySatisfy: [ :p | p message content = 'hi' ]).
    self assert: (panel statusLabel label asLowercase includesSubstring: 'wait').
    self deny: panel sendButton isEnabled.
    stub releaseGate.
    panel waitForPending.
    self assert: panel pendingRequest isNil description: 'pending cleared after reply'.
    self assert: (panel messagePresenters anySatisfy: [ :p | p message content = 'later' ]).
    self assert: panel statusLabel label isEmpty.
    self assert: panel sendButton isEnabled
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testStreamingClearsStatusOnDone [
    | pair session panel |
    pair := self stubSessionWithChunks: { self deltaChunkWithContent: 'hi' }.
    session := pair first.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    self assert: panel statusLabel label isEmpty.
    self assert: panel sendButton isEnabled.
    self assert: panel pendingRequest isNil
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testStreamingDeltasGrowAssistantContent [
    | pair session panel assistantTurns |
    pair := self stubSessionWithChunks: {
        self deltaChunkWithContent: 'a'.
        self deltaChunkWithContent: 'b'.
        self deltaChunkWithContent: 'c' }.
    session := pair first.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    assistantTurns := session conversation messages select: [ :m | m role = #assistant ].
    self assert: assistantTurns size equals: 1.
    self assert: assistantTurns first content equals: 'abc'
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testStreamingDoesNotDuplicateAssistantTurn [
    "Regression: the placeholder mutation pattern means the streaming finalise
     must reconcile into the placeholder, not addMessage: a new assistant turn."
    | pair session panel assistantTurns |
    pair := self stubSessionWithChunks: {
        self deltaChunkWithContent: 'hi'.
        self deltaChunkWithContent: ' there' }.
    session := pair first.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    assistantTurns := session conversation messages select: [ :m | m role = #assistant ].
    self assert: assistantTurns size equals: 1.
    self assert: assistantTurns first content equals: 'hi there'
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testStreamingMidStreamErrorPreservesPartialAssistantContent [
    "Two chunks land, then the stream raises. The partial assistant content
     ('ab') must remain in the transcript -- the placeholder is not removed
     -- and the status label/send button reflect the failure."
    | pair session stub panel assistantTurns |
    pair := self stubSessionWithChunks: {
        self deltaChunkWithContent: 'a'.
        self deltaChunkWithContent: 'b' }.
    session := pair first.
    stub := pair second.
    stub raiseOnPost: 'mid-stream boom'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    self assert: panel pendingRequest isNil.
    self assert: panel sendButton isEnabled.
    self assert: (panel statusLabel label asLowercase includesSubstring: 'error').
    self assert: (panel statusLabel label includesSubstring: 'mid-stream boom').
    assistantTurns := session conversation messages select: [ :m | m role = #assistant ].
    self assert: assistantTurns size equals: 1.
    self assert: assistantTurns first content equals: 'ab'
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testStreamingPlaceholderAssistantBubbleAppearsBeforeFirstChunk [
    | pair session stub panel assistantTurns |
    pair := self stubSessionWithChunks: { self deltaChunkWithContent: 'hi' }.
    session := pair first.
    stub := pair second.
    stub gateOn.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hello'.
    panel sendFromInput.
    "Before releasing the gate, the user message and the empty assistant
     placeholder should both be rendered."
    self assert: panel messagePresenters size equals: 2.
    assistantTurns := session conversation messages select: [ :m | m role = #assistant ].
    self assert: assistantTurns size equals: 1.
    self assert: assistantTurns first content equals: ''.
    stub releaseGate.
    panel waitForPending
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testStreamingPlaceholderEmitsAssistantSection [
    "An assistant message with empty content but non-nil rawStream is the
     streaming placeholder -- it must produce an [asst] section so the user
     sees the bubble exists before the first token lands."
    | session panel placeholder secs |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    placeholder := SmallChatLMMessage role: #assistant content: ''.
    placeholder rawStream: ''.
    session conversation addMessage: placeholder.
    secs := panel sections.
    self assert: (secs anySatisfy: [ :s | s kind = #assistant and: [ s message == placeholder ] ])
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testStreamingThinkingAppearingMidStreamDoesNotRaise [
    "When </think> closes mid-stream the cached presenter must instantiate
     the thinking widgets and re-apply its layout. The previous
     buildWithSpec rebuild path raised a DNU that opened Pharo's UI
     debugger in the live panel."
    | pair session panel placeholder presenter |
    pair := self stubSessionWithChunks: {
        self deltaChunkWithContent: '<think>'.
        self deltaChunkWithContent: 'reason</think>final' }.
    session := pair first.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    placeholder := session conversation messages last.
    presenter := panel messagePresenters last.
    self assert: placeholder content equals: 'final'.
    self assert: placeholder thinking equals: 'reason'.
    self assert: presenter hasThinking
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSystemMessagesNotRendered [
	| panel session |
	session := self stubSessionWithCannedReply: 'hello back'.
	panel := SmallChatLMChatPanel new
		session: session;
		yourself.
	self assert: (session conversation messages anySatisfy: [ :m | m role = #system ])
		description: 'precondition: session has a seeded system turn'.
	self deny: (panel messagePresenters anySatisfy: [ :p | p message role = #system ])
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testToolPlumbingMessageProducesToolCallSectionOnly [
    "An assistant message with empty content + non-empty toolCalls is plumbing.
     It must emit a #toolCall section per call but no [asst] row."
    | session panel tc plumbingMsg secs |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    tc := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
    plumbingMsg := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
    session conversation addMessage: plumbingMsg.
    secs := panel sections.
    self assert: (secs collect: [ :s | s kind ]) asArray equals: #( #toolCall ).
    self assert: (secs first) toolCall == tc
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testTranscriptFiltersIntermediateToolPlumbing [
	"After a tool-calling round, the conversation contains user / asst(tool_calls) /
	 tool(result) / asst(final). The transcript should only show user and the
	 final assistant bubble -- intermediate tool-call-only assistant messages and
	 #tool messages are not standalone bubbles."
	| session panel tc plumbingMsg toolMsg finalMsg |
	session := self stubSessionWithCannedReply: 'unused'.
	panel := SmallChatLMChatPanel new
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
	panel refreshMessages.
	self assert: panel messagePresenters size equals: 2.
	self assert: (panel messagePresenters first message role) equals: #user.
	self assert: (panel messagePresenters second message) equals: finalMsg
]
