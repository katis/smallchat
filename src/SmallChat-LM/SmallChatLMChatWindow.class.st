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
		'uiDeferrer'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

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
SmallChatLMChatWindow >> appendDelta: aString toAssistantMessage: aMessage [
    "Append one streaming delta to aMessage's raw buffer, re-run the
     thinking/content split so partial mid-tag chunks reclassify correctly,
     and push the new text into the cached presenter's widgets in place. On
     the first delta, clear the waiting status so the user sees content. When
     the chunk crosses a line break, force a layout refresh so the bubble
     re-measures and grows -- propagateNaturalHeight only feeds preferred
     sizes through a layout pass, not through plain text:."
    | client split |
    aMessage rawStream: aMessage rawStream , aString.
    client := session client.
    split := client splitThinkingAndContent: aMessage rawStream.
    aMessage thinking: (split at: 1).
    aMessage content: (split at: 2).
    statusLabel label isEmpty ifFalse: [ statusLabel label: '' ].
    (self presenterFor: aMessage) refreshFromMessage.
    (aString includes: Character lf) ifTrue: [ self refreshMessages ]
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
    "Send aString to the LM via complete:onDelta:. The placeholder assistant
     message is created up front so an empty bubble appears immediately; tokens
     are appended to it as deltas arrive. The snapshot passed to the client is a
     copy of the pre-placeholder conversation so the LM is asked to complete the
     user turn, not the empty assistant placeholder."
    | snapshot placeholder block |
    snapshot := session conversation copy.
    placeholder := SmallChatLMMessage role: #assistant content: '' thinking: nil.
    placeholder rawStream: ''.
    session conversation addMessage: placeholder.
    self refreshMessages.
    block := [
        | failure final |
        failure := nil.
        final := nil.
        [ final := session client
            complete: snapshot
            onDelta: [ :delta |
                uiDeferrer value: [ self appendDelta: delta toAssistantMessage: placeholder ] ] ]
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
    input := self newTextInput
        placeholder: 'message';
        yourself.
    sendButton := self newButton
        label: 'Send';
        action: [ self sendFromInput ];
        yourself
]

{ #category : 'initialization' }
SmallChatLMChatWindow >> initializeWindow: aWindow [
	aWindow
		title: 'smallchat';
		initialExtent: 640 @ 480
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> input [
	^ input
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> messagePresenters [
	"System turns are configuration, not transcript content; skip them so the
	 seeded system prompt does not appear as a chat bubble."
	^ (session conversation messages reject: [ :m | m role = #system ])
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

{ #category : 'accessing' }
SmallChatLMChatWindow >> uiDeferrer: aBlock [
    uiDeferrer := aBlock
]

{ #category : 'synchronising' }
SmallChatLMChatWindow >> waitForPending [
    | p |
    p := pendingRequest.
    p ifNil: [ ^ self ].
    [ p isTerminated ] whileFalse: [ Processor yield ]
]
