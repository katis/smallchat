"
Spec2 chat panel on top of SmallChatLMSession. Renders each turn as a SmallChatLMMessagePresenter stacked in a dynamic pane, plus a single-line input and a Send button. Per-message presenters are cached by message identity so the thinking-section fold state (closed by default) survives transcript refreshes.

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
		'messagesPane',
		'messagesContent',
		'presentersByMessage',
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
    (self presenterFor: placeholder) refreshFromMessage.
    (aString includes: Character lf) ifTrue: [ self refreshMessages ]
]

{ #category : 'private' }
SmallChatLMChatPanel >> beginPendingSendOf: aString [
    session conversation addUser: aString.
    statusLabel label: 'waiting...'.
    sendButton disable.
    self refreshMessages
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
    ^ SpBoxLayout newTopToBottom
        spacing: 4;
        add: messagesPane;
        add: statusLabel expand: false;
        add: (SpBoxLayout newLeftToRight
            spacing: 4;
            add: input;
            add: sendButton expand: false;
            yourself)
            expand: false;
        yourself
]

{ #category : 'private' }
SmallChatLMChatPanel >> dispatchSendOf: aString [
    | placeholder block |
    placeholder := SmallChatLMMessage role: #assistant content: '' thinking: nil.
    placeholder rawStream: ''.
    session conversation addMessage: placeholder.
    self refreshMessages.
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
     so the transcript doesn't carry a stranded empty assistant bubble. With
     partial content, leave the placeholder in place so the user keeps what
     was streamed before the failure."
    | text |
    (aPlaceholder rawStream isNil or: [ aPlaceholder rawStream isEmpty ])
        ifTrue: [ session conversation removeMessage: aPlaceholder ].
    text := anException messageText ifNil: [ anException class name ].
    statusLabel label: '[error: ' , text , ']'.
    sendButton enable.
    pendingRequest := nil.
    self refreshMessages
]

{ #category : 'private' }
SmallChatLMChatPanel >> finishStreamingWith: aFinalMessage placeholder: aPlaceholder [
    "Final reconcile: the streaming client returns a finalised SmallChatLMMessage
     built from the same accumulator we mirrored on aPlaceholder. Defensive copy
     of content/thinking covers any drift, then UI state resets. Note: we do NOT
     addMessage: aFinalMessage -- the placeholder IS the assistant turn. One
     final refreshMessages so the trailing partial line also grows the bubble."
    aPlaceholder content: aFinalMessage content.
    aPlaceholder thinking: aFinalMessage thinking.
    aPlaceholder rawStream: nil.
    (self presenterFor: aPlaceholder) refreshFromMessage.
    self refreshMessages.
    statusLabel label: ''.
    sendButton enable.
    pendingRequest := nil
]

{ #category : 'private' }
SmallChatLMChatPanel >> formatToolActivity: aToolCallsList results: aResultsDict [
	"Format a flat log of tool calls paired with their results. nil when the
	 list is empty so the presenter can hide its toggle."
	aToolCallsList isEmpty ifTrue: [ ^ nil ].
	^ String streamContents: [ :s |
		aToolCallsList doWithIndex: [ :tc :i |
			i > 1 ifTrue: [ s nextPutAll: String lf ].
			s
				nextPutAll: tc name;
				nextPutAll: '(';
				nextPutAll: tc arguments;
				nextPutAll: ') => ';
				nextPutAll: (aResultsDict at: tc id ifAbsent: [ '(no result)' ]) ] ]
]

{ #category : 'initialization' }
SmallChatLMChatPanel >> initializePresenters [
    session isNil ifTrue: [ session := SmallChatLMSession new ].
    presentersByMessage := IdentityDictionary new.
    uiDeferrer := [ :aBlock | UIManager default defer: aBlock ].
    messagesContent := self newPresenter.
    messagesContent layout: SpBoxLayout newTopToBottom.
    messagesPane := self newPresenter.
    messagesPane layout: (SpScrollableLayout with: messagesContent).
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
SmallChatLMChatPanel >> isHiddenFromTranscript: aMessage [
	"Hide system turns, #tool result messages, and assistant messages that are
	 empty tool-call-only plumbing. An assistant message with non-nil rawStream
	 is a streaming placeholder -- keep it visible so the bubble grows live even
	 before content arrives."
	aMessage role = #system ifTrue: [ ^ true ].
	aMessage role = #tool ifTrue: [ ^ true ].
	^ aMessage role = #assistant
		and: [ aMessage rawStream isNil
		and: [ (aMessage content isNil or: [ aMessage content isEmpty ])
		and: [ aMessage toolCalls notNil
		and: [ aMessage toolCalls notEmpty ] ] ] ]
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> messagePresenters [
	"System turns are configuration, not transcript. Tool plumbing -- the
	 assistant messages that only carry tool_calls and the #tool result
	 messages -- is not rendered as standalone bubbles either; those land
	 inside the final assistant bubble's tool-activity section (see the
	 message presenter's tool-activity toggle). What stays: user turns,
	 assistant messages with real content (or still streaming, indicated by
	 non-nil rawStream), and any other role Pharo might someday introduce."
	^ (session conversation messages
		reject: [ :m | self isHiddenFromTranscript: m ])
		collect: [ :m | self presenterFor: m ]
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> messagesContent [
    ^ messagesContent
]

{ #category : 'accessing' }
SmallChatLMChatPanel >> messagesPane [
    ^ messagesPane
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
SmallChatLMChatPanel >> presenterFor: aMessage [
	"Look up (or create) the presenter for aMessage and keep its tool-activity
	 summary in sync with the current conversation state. The summary walks back
	 to the previous user turn so intermediate tool plumbing from this same
	 response folds under this bubble's toggle."
	| presenter activity |
	presenter := presentersByMessage
		at: aMessage
		ifAbsentPut: [ SmallChatLMMessagePresenter on: aMessage ].
	aMessage role = #assistant ifTrue: [
		activity := self toolActivityTextFor: aMessage.
		presenter toolActivity: activity ].
	^ presenter
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

{ #category : 'private' }
SmallChatLMChatPanel >> refreshMessages [
    | inner |
    inner := SpBoxLayout newTopToBottom.
    self messagePresenters do: [ :p | inner add: p expand: false ].
    messagesContent layout: inner
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
	presentersByMessage isNil ifFalse: [ self refreshMessages ]
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

{ #category : 'private' }
SmallChatLMChatPanel >> toolActivityTextFor: anAssistantMessage [
	"Walk the conversation backwards from anAssistantMessage to the previous
	 non-plumbing message (user, system, or another final assistant). Collect
	 paired tool_call+tool-result messages and format them as a short log,
	 one call per pair. Returns nil when there was no tool activity before
	 this turn so the presenter can omit its toggle."
	| all idx calls results |
	all := session conversation messages.
	idx := all indexOf: anAssistantMessage.
	idx = 0 ifTrue: [ ^ nil ].
	calls := OrderedCollection new.
	results := Dictionary new.
	idx - 1 to: 1 by: -1 do: [ :i | | m isBoundary isPlumbing |
		m := all at: i.
		(m role = #assistant
			and: [ m toolCalls notNil and: [ m toolCalls notEmpty ] ])
			ifTrue: [ m toolCalls do: [ :tc | calls addFirst: tc ] ].
		m role = #tool ifTrue: [ results at: m toolCallId put: m content ].
		isPlumbing := (m role = #tool)
			or: [ m role = #assistant
				and: [ m toolCalls notNil
				and: [ m toolCalls notEmpty
				and: [ m content isNil or: [ m content isEmpty ] ] ] ] ].
		isBoundary := isPlumbing not.
		isBoundary ifTrue: [ ^ self formatToolActivity: calls results: results ] ].
	^ self formatToolActivity: calls results: results
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
