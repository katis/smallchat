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
    statusLabel label isEmpty ifFalse: [ statusLabel label: '' ].
    self rebuildSections
]

{ #category : 'private' }
SmallChatLMChatPanel >> beginPendingSendOf: aString [
    session conversation addUser: aString.
    statusLabel label: 'waiting...'.
    sendButton disable.
    self rebuildSections
]

{ #category : 'lifecycle' }
SmallChatLMChatPanel >> cleanup [
  "Release per-panel external bindings: terminate any in-flight reply fork
   and cancel the session's outstanding request. Idempotent. The host
   window calls this from whenClosedDo: before its own teardown."
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
	 first round's placeholder when the loop advanced through tool calls."
	self rebuildSections.
	statusLabel label: ''.
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
     Within an assistant message: thinking, then toolCalls (one section each),
     then content. Tool messages contribute their content as the matching
     toolCall section's output, not a standalone row."
    | result resultsByCallId msgs |
    msgs := session conversation messages.
    resultsByCallId := Dictionary new.
    msgs do: [ :m |
        m role = #tool ifTrue: [
            m toolCallId ifNotNil: [ :id |
                resultsByCallId at: id put: (m content ifNil: [ '' ]) ] ] ].
    result := OrderedCollection new.
    msgs do: [ :m |
        m role = #user ifTrue: [
            result add: (SmallChatLMTranscriptSection userOn: m) ].
        m role = #assistant ifTrue: [
            (m thinking notNil and: [ m thinking isEmpty not ]) ifTrue: [
                result add: (SmallChatLMTranscriptSection thinkingOn: m) ].
            (m toolCalls notNil and: [ m toolCalls isEmpty not ]) ifTrue: [
                m toolCalls do: [ :tc |
                    result add: (SmallChatLMTranscriptSection
                        toolCallOn: m
                        call: tc
                        result: (resultsByCallId at: tc id ifAbsent: [ nil ])) ] ].
            ((m content notNil and: [ m content isEmpty not ]) or: [ m rawStream notNil ]) ifTrue: [
                result add: (SmallChatLMTranscriptSection assistantOn: m) ] ] ].
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
    session := aSession.
    sectionList isNil ifFalse: [ self rebuildSections ]
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
