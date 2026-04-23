"
One chat turn in the window. Shows role + content always; when the
underlying message carries a non-empty thinking block, adds a
disclosure button that toggles the thinking body. Closed by default.

Fold state (#thinkingVisible) lives in the presenter, not the message
-- the model stays pure. SmallChatLMChatWindow caches presenters per
message identity so an expanded thinking block stays expanded when
the next reply lands.
"
Class {
	#name : 'SmallChatLMMessagePresenter',
	#superclass : 'SpPresenter',
	#instVars : [
		'message',
		'roleLabel',
		'contentText',
		'toggleButton',
		'thinkingText',
		'thinkingVisible'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'constants' }
SmallChatLMMessagePresenter class >> collapsedGlyph [
	^ 'â¸'
]

{ #category : 'constants' }
SmallChatLMMessagePresenter class >> expandedGlyph [
	^ 'â¾'
]

{ #category : 'instance creation' }
SmallChatLMMessagePresenter class >> on: aMessage [
	^ self basicNew setMessage: aMessage; initialize; yourself
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> contentText [
    ^ contentText
]

{ #category : 'layout' }
SmallChatLMMessagePresenter >> defaultLayout [
    | outer |
    outer := SpBoxLayout newTopToBottom
        spacing: 2;
        add: roleLabel expand: false;
        add: contentText expand: true;
        yourself.
    self hasThinking ifTrue: [
        outer add: toggleButton expand: false.
        self isThinkingVisible ifTrue: [
            outer add: thinkingText expand: true ] ].
    ^ outer
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> hasThinking [
	^ message thinking notNil
		and: [ message thinking isEmpty not ]
]

{ #category : 'initialization' }
SmallChatLMMessagePresenter >> initializePresenters [
    thinkingVisible := false.
    roleLabel := self newLabel label: (message role asString , ':').
    contentText := self newText
        beNotEditable;
        propagateNaturalHeight: true;
        text: (message content ifNil: [ '' ]);
        yourself.
    self hasThinking ifTrue: [
        toggleButton := self newButton
            label: self toggleLabel;
            action: [ self toggleThinking ];
            yourself.
        thinkingText := self newText
            beNotEditable;
            propagateNaturalHeight: true;
            text: message thinking;
            yourself ]
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> isThinkingVisible [
	^ thinkingVisible = true
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> message [
	^ message
]

{ #category : 'updating' }
SmallChatLMMessagePresenter >> refreshFromMessage [
    "Push the message's current content/thinking into the existing widgets in
     place. Used by the chat window between streaming deltas so we don't
     refreshMessages (and rebuild the entire pane) per token."
    | thinkingJustAppeared |
    thinkingJustAppeared := thinkingText isNil and: [ self hasThinking ].
    contentText text: (message content ifNil: [ '' ]).
    thinkingText isNil ifFalse: [
        thinkingText text: (message thinking ifNil: [ '' ]) ].
    thinkingJustAppeared ifTrue: [
        toggleButton := self newButton
            label: self toggleLabel;
            action: [ self toggleThinking ];
            yourself.
        thinkingText := self newText
            beNotEditable;
            propagateNaturalHeight: true;
            text: message thinking;
            yourself.
        (self respondsTo: #withWindowDo:) ifTrue: [
            self withWindowDo: [ :w | self needRebuild: false. self buildWithSpec ] ] ]
]

{ #category : 'initialization' }
SmallChatLMMessagePresenter >> setMessage: aMessage [
	message := aMessage
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> toggleLabel [
	| glyph |
	glyph := self isThinkingVisible
		ifTrue: [ self class expandedGlyph ]
		ifFalse: [ self class collapsedGlyph ].
	^ glyph , ' thinking'
]

{ #category : 'actions' }
SmallChatLMMessagePresenter >> toggleThinking [
	thinkingVisible := self isThinkingVisible not.
	self updateThinkingWidget
]

{ #category : 'private' }
SmallChatLMMessagePresenter >> updateThinkingWidget [
	toggleButton isNil ifFalse: [ toggleButton label: self toggleLabel ].
	"Rebuild the layout so the thinking body appears/disappears. Only
	 meaningful once the presenter has a window/widget; in unit tests we
	 exercise state without building, so skip the rebuild gracefully."
	(self respondsTo: #withWindowDo:) ifTrue: [
		self withWindowDo: [ :w | self needRebuild: false. self buildWithSpec ] ]
]
