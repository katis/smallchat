"
Spec2 chat window on top of SmallChatLMSession. Renders each turn as
a SmallChatLMMessagePresenter stacked in a dynamic pane, plus a
single-line input and a Send button. Per-message presenters are cached
by message identity so the thinking-section fold state (closed by
default) survives transcript refreshes.

Usage (from an evaluate call or workspace):
    UIManager default defer: [ SmallChatLMChatWindow new open ]

Deferring to the UI process matters when the window is opened from a
forked reader thread (e.g. an MCP tool). See CLAUDE.md for the MCP
constraint.
"
Class {
	#name : 'SmallChatLMChatWindow',
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
		'mcpStatusLabel'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'mcp status' }
SmallChatLMChatWindow class >> labelForMCPState: aState [
	"Three-state mapping for the header indicator. ASCII only (Pharo 13
	 Tonel round-trips unicode as mojibake in compiled method source)."
	aState running ifFalse: [ ^ 'MCP: offline' ].
	aState clientCount > 0 ifTrue: [ ^ 'MCP: connected' ].
	^ 'MCP: listening'
]

{ #category : 'world menu' }
SmallChatLMChatWindow class >> menuCommandOn: aBuilder [
	<worldMenu>
	(aBuilder item: #smallchat)
		parent: #Tools;
		order: 100;
		help: 'Open the smallchat agent chat window';
		icon: (self iconNamed: #smallConfiguration);
		action: [ UIManager default defer: [ self new open ] ]
]

{ #category : 'private' }
SmallChatLMChatWindow >> appendStreamingDelta: aString [
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

{ #category : 'mcp status' }
SmallChatLMChatWindow >> applyMCPState: aStateAnnouncement [
    "Refresh the header text from a state-change announcement. Called via
     uiDeferrer so mutation lands on the UI thread regardless of which
     process triggered the announcement."
    mcpStatusLabel label: (self class labelForMCPState: aStateAnnouncement)
]

{ #category : 'private' }
SmallChatLMChatWindow >> beginPendingSendOf: aString [
    session conversation addUser: aString.
    statusLabel label: 'waiting...'.
    sendButton disable.
    self refreshMessages
]

{ #category : 'layout' }
SmallChatLMChatWindow >> defaultLayout [
    ^ SpBoxLayout newTopToBottom
        spacing: 4;
        add: mcpStatusLabel expand: false;
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
SmallChatLMChatWindow >> dispatchSendOf: aString [
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
SmallChatLMChatWindow >> finishPendingWithError: anException placeholder: aPlaceholder [
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
SmallChatLMChatWindow >> finishStreamingWith: aFinalMessage placeholder: aPlaceholder [
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

{ #category : 'initialization' }
SmallChatLMChatWindow >> initializePresenters [
    session isNil ifTrue: [ session := SmallChatLMSession new ].
    presentersByMessage := IdentityDictionary new.
    uiDeferrer := [ :aBlock | UIManager default defer: aBlock ].
    messagesContent := self newPresenter.
    messagesContent layout: SpBoxLayout newTopToBottom.
    messagesPane := self newPresenter.
    messagesPane layout: (SpScrollableLayout with: messagesContent).
    statusLabel := self newLabel.
    mcpStatusLabel := self newLabel
        label: (self class labelForMCPState: SmallChatMCPTcpServer default currentState);
        yourself.
    input := self newTextInput
        placeholder: 'message';
        yourself.
    sendButton := self newButton
        label: 'Send';
        action: [ self sendFromInput ];
        yourself.
    self subscribeToMCPAnnouncer
]

{ #category : 'initialization' }
SmallChatLMChatWindow >> initializeWindow: aWindow [
	aWindow
		title: 'smallchat';
		initialExtent: 640 @ 480;
		whenClosedDo: [ self unsubscribeFromMCPAnnouncer ]
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> input [
	^ input
]

{ #category : 'private' }
SmallChatLMChatWindow >> isHiddenFromTranscript: aMessage [
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
SmallChatLMChatWindow >> mcpStatusLabel [
    ^ mcpStatusLabel
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> messagePresenters [
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
SmallChatLMChatWindow >> messagesContent [
    ^ messagesContent
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> messagesPane [
    ^ messagesPane
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> pendingRequest [
    ^ pendingRequest
]

{ #category : 'private' }
SmallChatLMChatWindow >> presenterFor: aMessage [
	^ presentersByMessage
		at: aMessage
		ifAbsentPut: [ SmallChatLMMessagePresenter on: aMessage ]
]

{ #category : 'private' }
SmallChatLMChatWindow >> refreshMessages [
    | inner |
    inner := SpBoxLayout newTopToBottom.
    self messagePresenters do: [ :p | inner add: p expand: false ].
    messagesContent layout: inner
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> sendButton [
    ^ sendButton
]

{ #category : 'private' }
SmallChatLMChatWindow >> sendFromInput [
    | text |
    pendingRequest isNil ifFalse: [ ^ self ].
    text := input text.
    (text isNil or: [ text isEmpty ]) ifTrue: [ ^ self ].
    self beginPendingSendOf: text.
    input text: ''.
    self dispatchSendOf: text
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> session [
	^ session
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> session: aSession [
	session := aSession.
	presentersByMessage isNil ifFalse: [ self refreshMessages ]
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> statusLabel [
    ^ statusLabel
]

{ #category : 'mcp status' }
SmallChatLMChatWindow >> subscribeToMCPAnnouncer [
    "Subscribe to SmallChatMCPStateChanged on the default TCP server so the
     header label tracks connect/disconnect events. The subscription is keyed
     by self so it can be removed with #unsubscribe: on window close."
    SmallChatMCPTcpServer default announcer
        when: SmallChatMCPStateChanged
        do: [ :ann | uiDeferrer value: [ self applyMCPState: ann ] ]
        for: self
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> uiDeferrer: aBlock [
    uiDeferrer := aBlock
]

{ #category : 'mcp status' }
SmallChatLMChatWindow >> unsubscribeFromMCPAnnouncer [
    "Remove this window's subscription from the default TCP server's
     announcer. Called from whenClosedDo: so the closed window does not
     react to later state changes."
    SmallChatMCPTcpServer default announcer unsubscribe: self
]

{ #category : 'synchronising' }
SmallChatLMChatWindow >> waitForPending [
    | p |
    p := pendingRequest.
    p ifNil: [ ^ self ].
    [ p isTerminated ] whileFalse: [ Processor yield ]
]
