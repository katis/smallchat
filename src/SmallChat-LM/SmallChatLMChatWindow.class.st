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
    | snapshot block |
    snapshot := session conversation.
    block := [
        | reply failure |
        failure := nil.
        [ reply := session client complete: snapshot ]
            on: Error
            do: [ :e | failure := e ].
        failure
            ifNil: [ uiDeferrer value: [ self finishPendingWith: reply ] ]
            ifNotNil: [ uiDeferrer value: [ self finishPendingWithError: failure ] ] ].
    pendingRequest := block newProcess.
    pendingRequest resume
]

{ #category : 'private' }
SmallChatLMChatWindow >> finishPendingWith: aMessage [
    session conversation addMessage: aMessage.
    statusLabel label: ''.
    sendButton enable.
    pendingRequest := nil.
    self refreshMessages
]

{ #category : 'private' }
SmallChatLMChatWindow >> finishPendingWithError: anException [
    | text |
    text := anException messageText ifNil: [ anException class name ].
    statusLabel label: '[error: ' , text , ']'.
    sendButton enable.
    pendingRequest := nil.
    self refreshMessages
]

{ #category : 'initialization' }
SmallChatLMChatWindow >> initializePresenters [
    session isNil ifTrue: [ session := SmallChatLMSession new ].
    presentersByMessage := IdentityDictionary new.
    uiDeferrer := [ :aBlock | UIManager default defer: aBlock ].
    messagesPane := self newPresenter.
    messagesPane layout: SpBoxLayout newTopToBottom.
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
	| layout |
	layout := SpBoxLayout newTopToBottom.
	self messagePresenters do: [ :p | layout add: p expand: false ].
	messagesPane layout: layout
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
