"
Spec2 chat panel on top of SmallChatLMSession. Master-detail transcript: a section list on the left, the selected section's full content on the right, and the tool result (when a #toolCall section is selected) across the bottom. Below those, the status label and the input + send button row.

Each conversation message decomposes into one or more SmallChatLMTranscriptSection rows in arrival order:
  - #user      : one per user message
  - #thinking  : one per assistant message that has non-empty thinking text
  - #toolCall  : one per SmallChatLMToolCall, output is the matched #tool message content
  - #assistant : one per assistant message with visible content (or non-nil rawStream during streaming)

Hosted by SmallChatWorkspaceWindow as a sub-presenter -- the workspace window owns the window-level concerns (title, whenClosedDo:, world menu) and embeds this panel via its layout.

Use #cleanup to release subscriptions and pending forks before the host window closes.
"
Class {
	#name : 'SmallChatLMChatPanel',
	#superclass : 'SpPresenter',
	#instVars : [
		'input',
		'sendButton',
		'session',
		'pendingRequest',
		'statusLabel',
		'uiDeferrer',
		'contentText',
		'outputText',
		'sectionList'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'rendering' }
SmallChatLMChatPanel class >> labelForSessionStatus: aSymbolOrNil [
  "Map a SmallChatLMSession status symbol to the chat panel's human
   readable label. Both #running and #awaiting collapse to the same
   'waiting...' string -- the dot in the agent tree carries the amber/
   green distinction; the panel's text only conveys 'am I in the middle
   of a turn?'. Errors get a generic floor text; the panel's own error
   path overwrites with the exception text."
  aSymbolOrNil = #running ifTrue: [ ^ 'waiting...' ].
  aSymbolOrNil = #awaiting ifTrue: [ ^ 'waiting...' ].
  aSymbolOrNil = #errored ifTrue: [ ^ '[error]' ].
  aSymbolOrNil = #cancelled ifTrue: [ ^ '[cancelled]' ].
  ^ ''
]

{ #category : 'private' }
SmallChatLMChatPanel >> appendStreamingDelta: aString [
    | placeholder client split |
    placeholder := session conversation messages last.
    (placeholder role = #assistant and: [ placeholder rawStream notNil ])
        ifFalse: [ ^ self ].
    client := session client.
    split := client splitThinkingAndContent: placeholder rawStream.
    placeholder thinking: (split at: 1).
    placeholder content: (split at: 2).
    self rebuildSections
]

{ #category : 'private' }
SmallChatLMChatPanel >> beginPendingSendOf: aString [
    "Append the user turn, flip the session into #running synchronously
     (the announcer reaction writes 'waiting...' into statusLabel via
     uiDeferrer), and disable the send button. Setting #running here means
     the user sees feedback before the dispatch fork has had a chance to
     run -- the fork's own status: #running call inside the streaming
     loop is idempotent."
    session conversation addUser: aString.
    session status: #running.
    sendButton disable.
    self rebuildSections
]

{ #category : 'lifecycle' }
SmallChatLMChatPanel >> cleanup [
  "Release per-panel external bindings: terminate any in-flight reply fork
   and cancel the session's outstanding request. Unsubscribes from the
   session's announcer first so a status flip racing the cancel does not
   call back. Idempotent. The host window calls this from whenClosedDo:
   before its own teardown."
  session ifNotNil: [ :s | s announcer unsubscribe: self ].
  session ifNotNil: [ :s | s cancelInFlight ].
  pendingRequest ifNotNil: [ :p |
    p isTerminated ifFalse: [ p terminate ] ].
  pendingRequest := nil
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> contentText [
    ^ contentText
]

{ #category : 'layout' }
SmallChatLMChatPanel >> defaultLayout [
    "Master-detail: section list left, selected section's content right,
     tool output across the bottom. Status label and input row stack
     beneath. Mirrors SmallChatMCPConnectionPanel."
    ^ SpBoxLayout newTopToBottom
        spacing: 4;
        add: (SpBoxLayout newLeftToRight
            spacing: 4;
            add: sectionList width: 240;
            add: contentText;
            yourself);
        add: outputText height: 140;
        add: statusLabel expand: false;
        add: (SpBoxLayout newLeftToRight
            spacing: 4;
            add: input;
            add: sendButton expand: false;
            yourself) expand: false;
        yourself
]

{ #category : 'private' }
SmallChatLMChatPanel >> dispatchSendOf: aString [
    | placeholder block |
    placeholder := SmallChatLMMessage role: #assistant content: '' thinking: nil.
    placeholder rawStream: ''.
    session conversation addMessage: placeholder.
    self rebuildSections.
    block := [
        | failure final |
        failure := nil.
        final := nil.
        [ final := session
            streamToolLoopUsingPlaceholder: placeholder
            onDelta: [ :delta |
                uiDeferrer value: [ self appendStreamingDelta: delta ] ] ]
            on: Error
            do: [ :e | failure := e ].
        failure
            ifNil: [ uiDeferrer value: [ self finishStreamingWith: final placeholder: placeholder ] ]
            ifNotNil: [ uiDeferrer value: [ self finishPendingWithError: failure placeholder: placeholder ] ] ].
    pendingRequest := block newProcess.
    pendingRequest resume
]

{ #category : 'private' }
SmallChatLMChatPanel >> finishPendingWithError: anException placeholder: aPlaceholder [
    "Stream raised. If no chunks landed, the placeholder is empty -- drop it
     so the transcript does not carry a stranded empty assistant section. With
     partial content, leave the placeholder in place so the user keeps what
     was streamed before the failure."
    | text |
    (aPlaceholder rawStream isNil or: [ aPlaceholder rawStream isEmpty ])
        ifTrue: [ session conversation removeMessage: aPlaceholder ].
    text := anException messageText ifNil: [ anException class name ].
    statusLabel label: '[error: ' , text , ']'.
    sendButton enable.
    pendingRequest := nil.
    self rebuildSections
]

{ #category : 'private' }
SmallChatLMChatPanel >> finishStreamingWith: aFinalMessage placeholder: aPlaceholder [
	"The streaming tool loop already finalises every placeholder it touches
	 (each round sets content/thinking/toolCalls and clears rawStream), so
	 nothing about the conversation needs reconciling here -- the final
	 placeholder IS aFinalMessage. Mutating aPlaceholder would corrupt the
	 first round's placeholder when the loop advanced through tool calls.
	 The statusLabel clears via the session's announcer when the loop
	 transitions to #idle."
	self rebuildSections.
	sendButton enable.
	pendingRequest := nil
]

{ #category : 'initialization' }
SmallChatLMChatPanel >> initializePresenters [
    session isNil ifTrue: [ session := SmallChatLMSession new ].
    uiDeferrer := [ :aBlock | UIManager default defer: aBlock ].
    sectionList := self newList.
    sectionList display: [ :section | section ifNil: [ '' ] ifNotNil: [ section label ] ].
    sectionList whenSelectionChangedDo: [ :sel | self showSection: sel selectedItem ].
    contentText := self newText.
    contentText beNotEditable.
    outputText := self newText.
    outputText beNotEditable.
    statusLabel := self newLabel.
    input := self newTextInput
        placeholder: 'message';
        yourself.
    sendButton := self newButton
        label: 'Send';
        action: [ self sendFromInput ];
        yourself
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> input [
	^ input
]

{ #category : 'private' }
SmallChatLMChatPanel >> onSessionStatusChanged: anAnnouncement [
  "Announcer reaction. Hops to UI via uiDeferrer (the announcement may be
   firing on a forked worker process from dispatchToolCall: or the streaming
   loop) and writes the human-readable mirror of the new status into
   statusLabel. Specific paths -- finishPendingWithError: most notably --
   may overwrite with richer text after this fires; that is intentional,
   the announcer reaction is the floor, the specific path is the topping."
  uiDeferrer value: [
    statusLabel label: (self class labelForSessionStatus: anAnnouncement status) ]
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> outputText [
    ^ outputText
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> pendingRequest [
    ^ pendingRequest
]

{ #category : 'private' }
SmallChatLMChatPanel >> rebuildSections [
    "Walk the conversation and refresh the list. Preserves the prior
     selection by =-equality so a streaming delta or new turn does not
     reset the user's focus row."
    | previous newItems |
    previous := sectionList selectedItem.
    newItems := self sections.
    sectionList items: newItems.
    previous ifNotNil: [ sectionList selectItem: previous ].
    self showSection: sectionList selectedItem
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> sectionList [
    ^ sectionList
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> sections [
	"Decompose conversation messages into list rows in strict arrival order.
	 The system prompt (if present) is rendered as the first #system section
	 so the user can see what context the LM is running with. Within an
	 assistant message: thinking, then content (the preamble shown to the
	 user), then toolCalls (one section each). A non-nil rawStream always
	 emits the assistant section -- it's the streaming-placeholder bubble.
	 Once streaming completes (rawStream is nil), whitespace-only content is
	 treated as empty -- LM Studio commonly emits a trailing '\n\n' on
	 tool-calling responses, and we don't want a stray empty [asst] row per
	 tool round. Tool messages contribute their content as the matching
	 toolCall section's output, not a standalone row."
	| result resultsByCallId msgs hasContent |
	msgs := session conversation messages.
	resultsByCallId := Dictionary new.
	msgs do: [ :m |
		m role = #tool ifTrue: [
			m toolCallId ifNotNil: [ :id |
				resultsByCallId at: id put: (m content ifNil: [ '' ]) ] ] ].
	hasContent := [ :str | str notNil and: [ str trimBoth isEmpty not ] ].
	result := OrderedCollection new.
	msgs do: [ :m |
		m role = #system ifTrue: [
			result add: (SmallChatLMTranscriptSection systemOn: m) ].
		m role = #user ifTrue: [
			result add: (SmallChatLMTranscriptSection userOn: m) ].
		m role = #assistant ifTrue: [
			(hasContent value: m thinking) ifTrue: [
				result add: (SmallChatLMTranscriptSection thinkingOn: m) ].
			(m rawStream notNil or: [ hasContent value: m content ]) ifTrue: [
				result add: (SmallChatLMTranscriptSection assistantOn: m) ].
			(m toolCalls notNil and: [ m toolCalls isEmpty not ]) ifTrue: [
				m toolCalls do: [ :tc |
					result add: (SmallChatLMTranscriptSection
						toolCallOn: m
						call: tc
						result: (resultsByCallId at: tc id ifAbsent: [ nil ])) ] ] ] ].
	^ result asArray
]

{ #category : 'binding' }
SmallChatLMChatPanel >> selectSection: aSection [
    "Test seam: programmatically pick a section, mirror it into the
     content/output panes synchronously."
    sectionList selectItem: aSection.
    self showSection: aSection
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> sendButton [
    ^ sendButton
]

{ #category : 'private' }
SmallChatLMChatPanel >> sendFromInput [
    | text |
    pendingRequest isNil ifFalse: [ ^ self ].
    text := input text.
    (text isNil or: [ text isEmpty ]) ifTrue: [ ^ self ].
    self beginPendingSendOf: text.
    input text: ''.
    self dispatchSendOf: text
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> session [
	^ session
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> session: aSession [
  "Bind aSession (replacing any previous one). Unsubscribes the old
   session's announcer and subscribes the new one so this panel's
   statusLabel reflects the bound session's lifecycle. Updates the label
   from the new status immediately so a freshly-bound session's dot and
   label agree."
  session ifNotNil: [ :old | old announcer unsubscribe: self ].
  session := aSession.
  aSession ifNotNil: [
    aSession announcer
      when: SmallChatLMSessionStatusChanged
      send: #onSessionStatusChanged:
      to: self ].
  sectionList isNil ifFalse: [ self rebuildSections ].
  statusLabel isNil ifFalse: [
    statusLabel label: (self class labelForSessionStatus: aSession status) ]
]

{ #category : 'private' }
SmallChatLMChatPanel >> showSection: aSectionOrNil [
    aSectionOrNil ifNil: [
        contentText text: ''.
        outputText text: ''.
        ^ self ].
    contentText text: aSectionOrNil content.
    outputText text: aSectionOrNil output
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> statusLabel [
    ^ statusLabel
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> uiDeferrer: aBlock [
    uiDeferrer := aBlock
]

{ #category : 'synchronising' }
SmallChatLMChatPanel >> waitForPending [
    | p |
    p := pendingRequest.
    p ifNil: [ ^ self ].
    [ p isTerminated ] whileFalse: [ Processor yield ]
]
