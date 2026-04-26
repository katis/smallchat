"
Controller for one chat session: holds the conversation + client and
exposes #sendUserInput: as the one-turn-at-a-time seam the UI drives.
Kept separate from the Spec2 window so the behaviour is testable without
Morphic / Spec2 / UI-process concerns.

Future tool-call loop will live here (#sendUserInput: would iterate while
the returned assistant message carries tool calls, dispatching them and
appending tool-result messages before the next #complete:).
"
Class {
	#name : 'SmallChatLMSession',
	#superclass : 'Object',
	#instVars : [
		'conversation',
		'client',
		'inFlightWorkers',
		'lspPendings',
		'workspace'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'cancellation' }
SmallChatLMSession >> cancelInFlight [
  "Cancel every tracked LSP pending request first so the server sees
   $/cancelRequest while the worker is still parked on its result wait,
   then terminate any worker process #trackInFlight: was told about."
  self lspPendings asArray do: [ :p |
    [ p cancel ] on: Error do: [ :_ | "best-effort cancel" ] ].
  self lspPendings removeAll: self lspPendings asArray.
  self inFlightWorkers asArray do: [ :p |
    p isTerminated ifFalse: [ p terminate ].
    self untrackInFlight: p ]
]

{ #category : 'accessing' }
SmallChatLMSession >> client [
	^ client
]

{ #category : 'accessing' }
SmallChatLMSession >> client: anLMClient [
	client := anLMClient
]

{ #category : 'accessing' }
SmallChatLMSession >> conversation [
	^ conversation
]

{ #category : 'tool dispatch' }
SmallChatLMSession >> dispatchToolCall: aToolCall [
	"Resolve aToolCall via the capability registry on a fresh worker
	 process; block on a Semaphore until the worker signals done. The fork
	 is the cancellation seam: closing the chat window terminates every
	 in-flight worker via #cancelInFlight. The session's workspace is
	 stamped onto the call before dispatch so the capability sees the
	 same workspace the chat is bound to (otherwise the registry falls
	 back to its currentWorkspace, which is global state)."
	| sem holder worker call |
	sem := Semaphore new.
	holder := Array new: 1.
	call := SmallChatCapabilityCall
		name: aToolCall name
		argumentsJson: aToolCall arguments.
	call session: self.
	call workspace: self workspace.
	worker := [
		| r |
		r := [ SmallChatCapabilityRegistry default run: aToolCall name with: call ]
			on: Error
			do: [ :e |
				SmallChatCapabilityResult error:
					('Error: ' , e class name , ' ' , (e messageText ifNil: [ '' ])) ].
		holder at: 1 put: r.
		sem signal ] newProcess.
	self trackInFlight: worker.
	worker resume.
	sem wait.
	self untrackInFlight: worker.
	^ (holder first
		ifNil: [ SmallChatCapabilityResult error:
			'Error: unknown tool ' , aToolCall name printString ])
		asTextForLM
]

{ #category : 'cancellation' }
SmallChatLMSession >> inFlightWorkers [
	"IdentitySet of forked Process instances for currently in-flight
	 capability dispatches. Lazy-initialised; cancelInFlight terminates
	 each entry."
	^ inFlightWorkers ifNil: [ inFlightWorkers := IdentitySet new ]
]

{ #category : 'initialization' }
SmallChatLMSession >> initialize [
	"Set up the conversation + client, then bind the always-mounted Pharo
	 workspace via the setter so its defaultSystemPrompt becomes the sole
	 system message. Tests that rebind via #workspace: get a clean swap."
	super initialize.
	conversation := SmallChatLMConversation new.
	client := SmallChatLMChatClient new.
	self workspace: SmallChatPharoWorkspace default
]

{ #category : 'private' }
SmallChatLMSession >> installSystemPromptFromWorkspace [
	"Replace any existing system message with one sourced from the bound
	 workspace's defaultSystemPrompt. Called from #workspace: so re-binding
	 a workspace swaps the prompt cleanly. No-op when the workspace is nil
	 or its prompt is empty."
	| msgs prompt newSystem |
	(workspace isNil or: [ conversation isNil ]) ifTrue: [ ^ self ].
	prompt := workspace class defaultSystemPrompt.
	(prompt isNil or: [ prompt isEmpty ]) ifTrue: [ ^ self ].
	msgs := conversation messages.
	msgs removeAllSuchThat: [ :m | m role = #system ].
	newSystem := SmallChatLMMessage role: #system content: prompt.
	msgs addFirst: newSystem
]

{ #category : 'cancellation' }
SmallChatLMSession >> lspPendings [
  "IdentitySet of LSP pending requests this session has been told about
   via #trackLspPending:. cancelInFlight cancels each before terminating
   workers so the LSP server gets a $/cancelRequest instead of a silent
   orphan."
  ^ lspPendings ifNil: [ lspPendings := IdentitySet new ]
]

{ #category : 'tool dispatch' }
SmallChatLMSession >> maxToolIterations [
	"Per-turn budget on tool-call rounds before the loop gives up and inserts
	 a synthetic error message. Tight enough to stop runaway loops, loose
	 enough to support a handful of honest tool hops in one answer."
	^ 8
]

{ #category : 'chat' }
SmallChatLMSession >> sendUserInput: aString [
	"Append the user turn, call the client, then loop as long as the reply
	 carries tool_calls: dispatch each, append tool-result messages, call
	 again. Gives up after maxToolIterations rounds. Returns the final
	 assistant message (always a content-bearing one, modulo the synthetic
	 budget-exhausted stub)."
	| reply iterations |
	(aString isNil or: [ aString isEmpty ]) ifTrue: [ ^ nil ].
	conversation addUser: aString.
	reply := client complete: conversation.
	conversation addMessage: reply.
	iterations := 0.
	[ reply toolCalls notNil and: [ reply toolCalls notEmpty ] ] whileTrue: [
		iterations := iterations + 1.
		iterations > self maxToolIterations ifTrue: [
			| synthetic |
			synthetic := SmallChatLMMessage
				role: #assistant
				content: 'Error: tool-call budget (' , self maxToolIterations printString , ' rounds) exhausted.'.
			conversation addMessage: synthetic.
			^ synthetic ].
		reply toolCalls do: [ :tc |
			conversation addTool: (self dispatchToolCall: tc) forCallId: tc id ].
		reply := client complete: conversation.
		conversation addMessage: reply ].
	^ reply
]

{ #category : 'chat' }
SmallChatLMSession >> sendUserInput: aString onDelta: aOneArgBlock [
	"Convenience entry point: add the user turn, seed a placeholder, and drive
	 the streaming tool loop. Used by session tests. The chat window bypasses
	 this method and calls streamToolLoopUsingPlaceholder:onDelta: directly so
	 the placeholder appears on the UI thread before the fork starts."
	| placeholder |
	(aString isNil or: [ aString isEmpty ]) ifTrue: [ ^ nil ].
	conversation addUser: aString.
	placeholder := SmallChatLMMessage role: #assistant content: '' thinking: nil.
	conversation addMessage: placeholder.
	^ self streamToolLoopUsingPlaceholder: placeholder onDelta: aOneArgBlock
]

{ #category : 'private' }
SmallChatLMSession >> snapshotExcluding: aMessage [
	"Shallow copy of the conversation with aMessage removed -- used to avoid
	 sending an empty placeholder to the LM during streaming."
	| snapshot |
	snapshot := conversation copy.
	snapshot messages remove: aMessage ifAbsent: [ ].
	^ snapshot
]

{ #category : 'chat' }
SmallChatLMSession >> streamToolLoopUsingPlaceholder: initialPlaceholder onDelta: aOneArgBlock [
	"Drive the tool-calling streaming loop. initialPlaceholder must already be
	 the last message in the conversation; its rawStream is (re-)initialised to
	 an empty string and mutated as chunks arrive. On each client round the
	 current placeholder is reconciled from the reply. If the reply carries
	 tool_calls, each call is dispatched and a tool-result message appended; a
	 fresh placeholder is then added and the loop re-enters. Budget exhaustion
	 appends a synthetic error message and returns it."
	| iterations placeholder |
	placeholder := initialPlaceholder.
	iterations := 0.
	[ true ] whileTrue: [
		| reply snapshot |
		placeholder rawStream: ''.
		snapshot := self snapshotExcluding: placeholder.
		reply := client
			complete: snapshot
			onDelta: [ :d |
				placeholder rawStream: placeholder rawStream , d.
				aOneArgBlock value: d ].
		placeholder content: reply content.
		placeholder thinking: reply thinking.
		placeholder toolCalls: reply toolCalls.
		placeholder rawStream: nil.
		(placeholder toolCalls isNil or: [ placeholder toolCalls isEmpty ])
			ifTrue: [ ^ placeholder ].
		iterations := iterations + 1.
		iterations > self maxToolIterations ifTrue: [
			| synthetic |
			synthetic := SmallChatLMMessage
				role: #assistant
				content: 'Error: tool-call budget (' , self maxToolIterations printString , ' rounds) exhausted.'.
			conversation addMessage: synthetic.
			^ synthetic ].
		placeholder toolCalls do: [ :tc |
			conversation addTool: (self dispatchToolCall: tc) forCallId: tc id ].
		placeholder := SmallChatLMMessage role: #assistant content: '' thinking: nil.
		conversation addMessage: placeholder ]
]

{ #category : 'cancellation' }
SmallChatLMSession >> trackInFlight: aProcess [
	self inFlightWorkers add: aProcess
]

{ #category : 'cancellation' }
SmallChatLMSession >> trackLspPending: aPending [
  self lspPendings add: aPending
]

{ #category : 'rendering' }
SmallChatLMSession >> transcriptText [
	^ String streamContents: [ :s |
		conversation messages do: [ :msg |
			s
				nextPutAll: msg role asString;
				nextPutAll: ': ';
				nextPutAll: msg content;
				nextPut: Character lf;
				nextPut: Character lf ] ]
]

{ #category : 'cancellation' }
SmallChatLMSession >> untrackInFlight: aProcess [
	self inFlightWorkers remove: aProcess ifAbsent: [ ]
]

{ #category : 'cancellation' }
SmallChatLMSession >> untrackLspPending: aPending [
  self lspPendings remove: aPending ifAbsent: [ ]
]

{ #category : 'accessing' }
SmallChatLMSession >> workspace [
	"The workspace this chat session is bound to. Stamped onto every tool
	 call before dispatch so capabilities see aCall workspace = this.
	 #initialize binds the always-mounted Pharo workspace so the lazy default
	 is unnecessary; tests that build a session by hand and skip init still
	 fall back to it."
	^ workspace ifNil: [ workspace := SmallChatPharoWorkspace default ]
]

{ #category : 'accessing' }
SmallChatLMSession >> workspace: aWorkspace [
	"Bind this session to aWorkspace, refresh the live client's catalog so
	 the LM only sees capabilities applicable to the workspace kind, and
	 ensure the conversation carries exactly one system message, sourced
	 from the workspace's defaultSystemPrompt. Re-binding replaces the
	 prior system message rather than appending so the prompt always
	 reflects the currently bound workspace. Mock clients that do not know
	 toolCatalog: are left alone."
	workspace := aWorkspace.
	(client notNil and: [ client respondsTo: #toolCatalog: ])
		ifTrue: [ client toolCatalog: (SmallChatLMCapabilityCatalog forWorkspace: aWorkspace) ].
	self installSystemPromptFromWorkspace
]
