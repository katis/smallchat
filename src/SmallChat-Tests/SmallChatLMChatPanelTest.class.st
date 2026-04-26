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
SmallChatLMChatPanelTest >> testFinishStreamingDoesNotMutateInitialPlaceholderAfterToolLoopAdvanced [
	"Regression: when the streaming tool loop advances ``placeholder`` to a fresh
	 assistant message each round, the FINAL message returned by the loop is a
	 different object than the initial placeholder ``dispatchSendOf:`` passed in.
	 ``finishStreamingWith:placeholder:`` must not copy the FINAL's content/thinking
	 onto the FIRST placeholder -- doing so duplicates the final answer at the
	 first placeholder's position and wipes out whatever the first round emitted."
	| session panel firstPlaceholder finalMessage tc |
	session := self stubSessionWithCannedReply: 'unused'.
	panel := SmallChatLMChatPanel new
		session: session;
		uiDeferrer: [ :blk | blk value ];
		yourself.
	tc := SmallChatLMToolCall id: 'c1' name: 'noop' arguments: '{}'.
	firstPlaceholder := SmallChatLMMessage role: #assistant content: '' thinking: 'first round thinking'.
	firstPlaceholder toolCalls: { tc }.
	finalMessage := SmallChatLMMessage role: #assistant content: 'final answer' thinking: nil.
	panel finishStreamingWith: finalMessage placeholder: firstPlaceholder.
	self assert: firstPlaceholder content equals: ''.
	self assert: firstPlaceholder thinking equals: 'first round thinking'.
	self assert: firstPlaceholder toolCalls equals: { tc }
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testInitializeBuildsAllPresenters [
  | panel |
  panel := SmallChatLMChatPanel new.
  self assert: panel input notNil.
  self assert: panel sendButton notNil.
  self assert: panel sectionList notNil.
  self assert: panel contentText notNil.
  self assert: panel outputText notNil.
  self assert: panel statusLabel notNil
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testNewTurnPreservesPriorSelection [
    | session panel firstUser |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    session conversation addUser: 'first'.
    panel rebuildSections.
    firstUser := panel sectionList items first.
    panel selectSection: firstUser.
    "Second turn lands."
    session conversation addAssistant: 'reply'.
    panel rebuildSections.
    self assert: panel sectionList selectedItem notNil.
    self assert: panel sectionList selectedItem kind equals: #user.
    self assert: panel sectionList selectedItem message content equals: 'first'
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testRebuildSectionsPopulatesSectionList [
    | session panel |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    session conversation addUser: 'hi'.
    panel rebuildSections.
    self assert: panel sectionList items size equals: 1.
    self assert: (panel sectionList items first) kind equals: #user
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
SmallChatLMChatPanelTest >> testSectionsOrderWithinAssistantIsThinkingThenContentThenToolCalls [
	"When a single assistant message carries thinking, a content preamble, AND
	 tool calls, the sections must reflect chronological model output: thought
	 first, then the preamble shown to the user, then the action. The previous
	 order put the action ahead of the preamble, which read as out of order."
	| session panel msg tc secs |
	session := self stubSessionWithCannedReply: 'unused'.
	panel := SmallChatLMChatPanel new
		session: session;
		uiDeferrer: [ :blk | blk value ];
		yourself.
	tc := SmallChatLMToolCall id: 'c1' name: 'noop' arguments: '{}'.
	msg := SmallChatLMMessage role: #assistant content: 'let me check' thinking: 'reasoning'.
	msg toolCalls: { tc }.
	session conversation addMessage: msg.
	secs := panel sections.
	self assert: (secs collect: [ :s | s kind ]) asArray
		equals: #( #thinking #assistant #toolCall )
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSelectingNilClearsBothPanes [
    | session panel |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    session conversation addUser: 'hello'.
    panel selectSection: panel sections first.
    panel selectSection: nil.
    self assert: panel contentText text asString isEmpty.
    self assert: panel outputText text asString isEmpty
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSelectingThinkingSectionShowsThinkingText [
    | session panel msg secs |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    msg := SmallChatLMMessage role: #assistant content: 'final' thinking: 'step by step'.
    session conversation addMessage: msg.
    secs := panel sections.
    panel selectSection: (secs detect: [ :s | s kind = #thinking ]).
    self assert: panel contentText text asString equals: 'step by step'.
    self assert: panel outputText text asString isEmpty
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testSelectingToolCallShowsArgsInContentAndResultInOutput [
    "Problem 2 regression: the tool result text lands in the dedicated bottom
     pane (which is its own SpTextPresenter, not a tiny inline section that
     collapsed under the old layout)."
    | session panel tc plumbingMsg toolMsg toolSec |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    tc := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{"code":"3+4"}'.
    plumbingMsg := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
    session conversation addMessage: plumbingMsg.
    toolMsg := SmallChatLMMessage role: #tool content: '7' toolCallId: 'c1'.
    session conversation addMessage: toolMsg.
    toolSec := panel sections detect: [ :s | s kind = #toolCall ].
    panel selectSection: toolSec.
    self assert: panel contentText text asString equals: 'evaluate({"code":"3+4"})'.
    self assert: panel outputText text asString equals: '7'
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
SmallChatLMChatPanelTest >> testSendFromInputAppendsSectionForEachMessage [
    | panel session secs |
    session := self stubSessionWithCannedReply: 'hello back'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    panel input text: 'hi'.
    panel sendFromInput.
    panel waitForPending.
    secs := panel sectionList items.
    self assert: secs size equals: 2.
    self assert: secs first kind equals: #user.
    self assert: secs last kind equals: #assistant
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
    self assert: (panel sectionList items anySatisfy: [ :s | s message content = 'hi' ]).
    self assert: (panel statusLabel label asLowercase includesSubstring: 'wait').
    self deny: panel sendButton isEnabled.
    stub releaseGate.
    panel waitForPending.
    self assert: panel pendingRequest isNil description: 'pending cleared after reply'.
    self assert: (panel sectionList items anySatisfy: [ :s | s message content = 'later' ]).
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
SmallChatLMChatPanelTest >> testStreamingDeltasUpdateSectionList [
    | pair session panel asstSec |
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
    asstSec := panel sectionList items detect: [ :s | s kind = #assistant ].
    self assert: asstSec message content equals: 'hi there'
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
SmallChatLMChatPanelTest >> testStreamingPlaceholderAssistantSectionAppearsBeforeFirstChunk [
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
    "Before releasing the gate, user + streaming-placeholder asst sections both visible."
    self assert: panel sectionList items size equals: 2.
    self assert: (panel sectionList items at: 1) kind equals: #user.
    self assert: (panel sectionList items at: 2) kind equals: #assistant.
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
SmallChatLMChatPanelTest >> testStreamingThinkingAppearsAsSeparateSection [
    "When </think> closes mid-stream the section list gains a [thnk] row alongside
     the [asst] row, both backed by the same placeholder message."
    | pair session panel placeholder kinds |
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
    self assert: placeholder content equals: 'final'.
    self assert: placeholder thinking equals: 'reason'.
    kinds := panel sectionList items collect: [ :s | s kind ].
    self assert: (kinds includes: #thinking).
    self assert: (kinds includes: #assistant)
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
    self deny: (panel sections anySatisfy: [ :s | s message role = #system ])
]

{ #category : 'tests' }
SmallChatLMChatPanelTest >> testToolCallWithoutResultShowsEmptyOutput [
    | session panel tc plumbingMsg toolSec |
    session := self stubSessionWithCannedReply: 'unused'.
    panel := SmallChatLMChatPanel new
        session: session;
        uiDeferrer: [ :blk | blk value ];
        yourself.
    tc := SmallChatLMToolCall id: 'c1' name: 'evaluate' arguments: '{}'.
    plumbingMsg := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
    session conversation addMessage: plumbingMsg.
    toolSec := panel sections first.
    panel selectSection: toolSec.
    self assert: panel outputText text asString isEmpty
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
