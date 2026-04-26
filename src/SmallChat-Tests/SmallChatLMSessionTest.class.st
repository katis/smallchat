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
SmallChatLMSessionTest >> testApplyProfileSetsNameModelAndSystemPrompt [
  "applyProfile: stamps the profile's identity onto the session: name copied
   for tree-row display, profile pointer kept for re-application, model swapped
   on the chat client, and the conversation's system message replaced with the
   profile's prompt so subsequent turns run under it."
  | session profile firstSystem model |
  model := SmallChatAgentProfile availableModels first.
  profile := SmallChatAgentProfile new
    name: 'Coder';
    modelName: model;
    systemPrompt: 'be terse';
    yourself.
  session := SmallChatLMSession new.
  session applyProfile: profile.
  self assert: session name equals: 'Coder'.
  self assert: session profile == profile.
  self assert: session client modelName equals: model.
  firstSystem := session conversation messages
    detect: [ :m | m role = #system ]
    ifNone: [ nil ].
  self assert: firstSystem notNil.
  self assert: firstSystem content equals: 'be terse'
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testCancelInFlightCancelsTrackedLspPendingsBeforeTerminatingWorkers [
  "Closing the chat window calls cancelInFlight; any tracked LSP pending
   request must be #cancel'd so the server sees a $/cancelRequest before
   the worker process is terminated and the response is silently dropped.
   Duck-typed stub stands in for a real SmallChatLSPPendingRequest so
   SmallChat-Tests doesn't pull SmallChat-LSP."
  | session pending worker |
  session := SmallChatLMSession new.
  pending := SmallChatLMSessionTestStubCancellable new.
  session trackLspPending: pending.
  worker := [ (Delay forSeconds: 60) wait ] newProcess.
  session trackInFlight: worker.
  worker resume.
  session cancelInFlight.
  self assert: pending cancelCount equals: 1.
  self assert: worker isTerminated.
  self deny: (session inFlightWorkers includes: worker)
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testCancelInFlightTerminatesWorker [
	"cancelInFlight terminates any process that #trackInFlight: has been
	 told about. The chat window calls this on close so a slow capability
	 doesn't outlive the UI it was driving."
	| session worker |
	session := SmallChatLMSession new.
	worker := [ (Delay forSeconds: 60) wait ] newProcess.
	session trackInFlight: worker.
	worker resume.
	self assert: (session inFlightWorkers includes: worker).
	session cancelInFlight.
	self assert: worker isTerminated.
	self deny: (session inFlightWorkers includes: worker)
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testConversationSeededWithDefaultPharoWorkspacePrompt [
	"#initialize binds the always-mounted Pharo workspace, which seeds the
	 conversation with that workspace's defaultSystemPrompt. Pin the
	 source-of-truth so a TS chat does not silently reuse a Pharo prompt
	 cached at config-time."
	| session first |
	session := SmallChatLMSession new.
	first := session conversation messages first.
	self assert: first role equals: #system.
	self assert: first content equals: SmallChatPharoWorkspace defaultSystemPrompt
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testDispatchToolCallReportsUnknownTool [
	"Names not present in the capability registry surface as a descriptive
	 error string -- the model can course-correct rather than the session
	 silently stalling."
	| session call result |
	session := SmallChatLMSession new.
	call := SmallChatLMToolCall id: 'c1' name: 'nope.does-not-exist' arguments: '{}'.
	result := session dispatchToolCall: call.
	self assert: (result includesSubstring: 'unknown tool')
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testDispatchToolCallRoutesViaCapabilityRegistry [
	"After M4, SmallChatLMSession>>dispatchToolCall: looks up the tool name in
	 SmallChatCapabilityRegistry and returns asTextForLM. eval.smalltalk is
	 a real, registered capability."
	| session call result |
	session := SmallChatLMSession new.
	call := SmallChatLMToolCall id: 'c1' name: 'eval.smalltalk' arguments: '{"code":"3 + 4"}'.
	result := session dispatchToolCall: call.
	self assert: result equals: '7'
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testDispatchToolCallStampsSessionsWorkspaceOntoCall [
	"The chat session should pass its bound workspace to the registry so each
	 capability sees aCall workspace = session workspace. Uses the recording
	 test fixture to capture the value."
	| ws session call |
	ws := SmallChatPharoWorkspace default.
	SmallChatCapabilityWorkspaceRecordingForTests reset.
	session := SmallChatLMSession new workspace: ws; yourself.
	call := SmallChatLMToolCall id: 'c1' name: 'test.workspace.recording' arguments: '{}'.
	session dispatchToolCall: call.
	self
		assert: SmallChatCapabilityWorkspaceRecordingForTests lastSeenWorkspace == ws
		description: 'dispatch must stamp session.workspace onto the SmallChatCapabilityCall'
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
SmallChatLMSessionTest >> testNameAccessor [
  "Sessions carry a user-facing name so the agent tree can label its rows."
  | session |
  session := SmallChatLMSession new.
  session name: 'Coder'.
  self assert: session name equals: 'Coder'
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testNewSessionStatusIsIdle [
  "A freshly built session reports #idle so the agent tree can render the
   default hollow dot without the rest of the state machine being wired
   yet -- this is the pin for the lazy default."
  | session |
  session := SmallChatLMSession new.
  self assert: session status equals: #idle
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testProfileAccessor [
  "Sessions remember which agent profile they were built from so later
   slices can re-apply or display profile-derived data."
  | session profile |
  profile := SmallChatAgentProfile new
    name: 'Coder';
    yourself.
  session := SmallChatLMSession new.
  session profile: profile.
  self assert: session profile == profile
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testProfileWorkspaceConstructor [
  "SmallChatLMSession class>>profile:workspace: composes #applyProfile:
   then #workspace: so the session lands ready-to-use: profile bound, name
   defaulted from profile, profile prompt installed, and tool catalog
   filtered to the workspace kind."
  | profile ts session firstSystem model |
  model := SmallChatAgentProfile availableModels first.
  profile := SmallChatAgentProfile new
    name: 'Coder';
    modelName: model;
    systemPrompt: 'be terse';
    yourself.
  ts := SmallChatTsWorkspace new name: 'ts-fixture'; yourself.
  session := SmallChatLMSession profile: profile workspace: ts.
  self assert: session profile == profile.
  self assert: session workspace == ts.
  self assert: session name equals: 'Coder'.
  firstSystem := session conversation messages
    detect: [ :m | m role = #system ]
    ifNone: [ nil ].
  self assert: firstSystem notNil.
  self assert: firstSystem content equals: 'be terse'
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
SmallChatLMSessionTest >> testSendUserInputDispatchesToolCallsAndLoopsToFinalAnswer [
	| mock tc toolReply finalReply session result nonSystem roles |
	mock := SmallChatLMMockClient new.
	tc := SmallChatLMToolCall id: 'c1' name: 'eval.smalltalk' arguments: '{"code":"3 + 4"}'.
	toolReply := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
	finalReply := SmallChatLMMessage role: #assistant content: 'The answer is 7.'.
	mock queueReply: toolReply.
	mock queueReply: finalReply.
	session := SmallChatLMSession new client: mock; yourself.
	result := session sendUserInput: 'what is 3 + 4?'.
	self assert: result equals: finalReply.
	self assert: mock callCount equals: 2.
	nonSystem := session conversation messages reject: [ :m | m role = #system ].
	roles := nonSystem collect: [ :m | m role ].
	self assert: roles asArray equals: #(#user #assistant #tool #assistant).
	self assert: (nonSystem third toolCallId) equals: 'c1'.
	self assert: (nonSystem third content) equals: '7'
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testSendUserInputOnDeltaStreamsContentAndDispatchesTools [
	| mock tc toolReply finalReply session deltas result |
	mock := SmallChatLMMockClient new.
	tc := SmallChatLMToolCall id: 'c1' name: 'eval.smalltalk' arguments: '{"code":"2 + 2"}'.
	"tool-call reply has empty content -- no delta should fire for it"
	toolReply := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
	finalReply := SmallChatLMMessage role: #assistant content: 'it is 4'.
	mock queueReply: toolReply.
	mock queueReply: finalReply.
	session := SmallChatLMSession new client: mock; yourself.
	deltas := OrderedCollection new.
	result := session sendUserInput: 'add them' onDelta: [ :d | deltas add: d ].
	self assert: result equals: finalReply.
	self assert: mock callCount equals: 2.
	self assert: deltas asArray equals: #('it is 4')
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testSendUserInputStopsAfterToolIterationBudget [
	| mock session result tc replyWithCall |
	mock := SmallChatLMMockClient new.
	tc := SmallChatLMToolCall id: 'c1' name: 'eval.smalltalk' arguments: '{"code":"1"}'.
	"Queue enough tool-call replies to trip the 30-round budget, plus one more."
	1 to: 34 do: [ :_ |
		replyWithCall := SmallChatLMMessage role: #assistant content: '' toolCalls: { tc }.
		mock queueReply: replyWithCall ].
	session := SmallChatLMSession new client: mock; yourself.
	result := session sendUserInput: 'loop forever'.
	self assert: result role equals: #assistant.
	self assert: (result content includesSubstring: 'budget').
	self assert: mock callCount <= 31.
	"Exactly 1 initial + 30 tool rounds = 31 calls max."
	self assert: mock callCount equals: 31
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testSessionInitializesWithChatClient [
	self assert: SmallChatLMSession new client class equals: SmallChatLMChatClient
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testStatusSetterAnnouncesChange [
  "status: emits a SmallChatLMSessionStatusChanged carrying the session
   and the new status so the agent tree (and any future subscriber) can
   refresh just that row when a turn changes lifecycle phase."
  | session received |
  session := SmallChatLMSession new.
  received := OrderedCollection new.
  session announcer
    when: SmallChatLMSessionStatusChanged
    do: [ :a | received add: a ]
    for: self.
  session status: #running.
  self assert: received size equals: 1.
  self assert: received first session == session.
  self assert: received first status equals: #running
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testStatusSetterIsIdempotent [
  "Setting status: to the current value is a no-op -- no announcement is
   fired so subscribers never thrash on self-transitions (e.g. a streaming
   delta arriving while already #running)."
  | session received |
  session := SmallChatLMSession new.
  session status: #running.
  received := OrderedCollection new.
  session announcer
    when: SmallChatLMSessionStatusChanged
    do: [ :a | received add: a ]
    for: self.
  session status: #running.
  self assert: received isEmpty
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

{ #category : 'tests' }
SmallChatLMSessionTest >> testWorkspaceBindReplacesSystemPromptWithWorkspaceDefault [
	"Binding a workspace must leave the conversation with exactly one system
	 message, sourced from aWorkspace class defaultSystemPrompt. A TS chat
	 must not inherit the Pharo prompt that an earlier #initialize might
	 have seeded."
	| session ts systemMessages |
	ts := SmallChatTsWorkspace new name: 'ts-fixture'; yourself.
	session := SmallChatLMSession new workspace: ts; yourself.
	systemMessages := session conversation messages select: [ :m | m role = #system ].
	self assert: systemMessages size equals: 1.
	self
		assert: systemMessages first content
		equals: SmallChatTsWorkspace defaultSystemPrompt
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testWorkspacePromptOverriddenByConfigOverride [
	"SmallChatConfig systemPromptOverride wraps the SMALLCHAT_LM_SYSTEM_PROMPT
	 env var. When it is set (real env, or test-stubbed via
	 systemPromptOverride:), workspace: must seed that override instead of
	 the workspace's defaultSystemPrompt -- otherwise the env hook is dead
	 once workspace-driven seeding lands."
	| saved session |
	saved := SmallChatConfig systemPromptOverride.
	[ SmallChatConfig systemPromptOverride: 'OVERRIDE-PROMPT'.
	  session := SmallChatLMSession new.
	  self
		assert: session conversation messages first content
		equals: 'OVERRIDE-PROMPT' ]
		ensure: [ SmallChatConfig systemPromptOverride: saved ]
]

{ #category : 'tests' }
SmallChatLMSessionTest >> testWorkspaceRebindKeepsProfilePrompt [
  "After applyProfile: stamps a system prompt, a subsequent workspace:
   bind must NOT overwrite it with the workspace's defaultSystemPrompt --
   the profile's prompt is the user's explicit choice and must win.
   Tool-catalog wiring still happens (asserted indirectly: no exception
   from the workspace setter on a session whose client has a toolCatalog:
   selector)."
  | session profile ts firstSystem model |
  model := SmallChatAgentProfile availableModels first.
  profile := SmallChatAgentProfile new
    name: 'Coder';
    modelName: model;
    systemPrompt: 'be terse';
    yourself.
  ts := SmallChatTsWorkspace new name: 'ts-fixture'; yourself.
  session := SmallChatLMSession new.
  session applyProfile: profile.
  session workspace: ts.
  firstSystem := session conversation messages
    detect: [ :m | m role = #system ]
    ifNone: [ nil ].
  self assert: firstSystem notNil.
  self assert: firstSystem content equals: 'be terse'
]
