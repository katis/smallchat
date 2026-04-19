"
Minimal Spec2 chat window on top of SmallChatLMSession. A read-only
transcript pane, a single-line input, and a Send button. All real
behaviour lives in SmallChatLMSession; this class wires Spec2 to it.

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
		'transcript',
		'input',
		'sendButton',
		'session'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'layout' }
SmallChatLMChatWindow >> defaultLayout [
	^ SpBoxLayout newTopToBottom
		spacing: 4;
		add: transcript;
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
	session := SmallChatLMSession new.
	transcript := self newText
		beNotEditable;
		yourself.
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

{ #category : 'private' }
SmallChatLMChatWindow >> sendFromInput [
	| text |
	text := input text.
	(text isNil or: [ text isEmpty ]) ifTrue: [ ^ self ].
	session sendUserInput: text.
	transcript text: session transcriptText.
	input text: ''
]

{ #category : 'accessing' }
SmallChatLMChatWindow >> session [
	^ session
]
