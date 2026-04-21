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
		'presentersByMessage'
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

{ #category : 'layout' }
SmallChatLMChatWindow >> defaultLayout [
	^ SpBoxLayout newTopToBottom
		spacing: 4;
		add: messagesPane;
		add: (SpBoxLayout newLeftToRight
			spacing: 4;
			add: input;
			add: sendButton expand: false;
			yourself)
			expand: false;
		yourself
]

{ #category : 'initialization' }
SmallChatLMChatWindow >> initializePresenters [
	session isNil ifTrue: [ session := SmallChatLMSession new ].
	presentersByMessage := IdentityDictionary new.
	messagesPane := self newPresenter.
	messagesPane layout: SpBoxLayout newTopToBottom.
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

{ #category : 'private' }
SmallChatLMChatWindow >> sendFromInput [
	| text |
	text := input text.
	(text isNil or: [ text isEmpty ]) ifTrue: [ ^ self ].
	session sendUserInput: text.
	self refreshMessages.
	input text: ''
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
