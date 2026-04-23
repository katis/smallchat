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
		'thinkingVisible',
		'toolActivity',
		'toolActivityVisible',
		'toolActivityToggle',
		'toolActivityText'
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
    self hasToolActivity ifTrue: [
        outer add: toolActivityToggle expand: false.
        self isToolActivityVisible ifTrue: [
            outer add: toolActivityText expand: true ] ].
    ^ outer
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> hasThinking [
	^ message thinking notNil
		and: [ message thinking isEmpty not ]
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> hasToolActivity [
	^ toolActivity notNil and: [ toolActivity isEmpty not ]
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
SmallChatLMMessagePresenter >> isToolActivityVisible [
	^ toolActivityVisible = true
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> message [
	^ message
]

{ #category : 'updating' }
SmallChatLMMessagePresenter >> refreshFromMessage [
    "Push the message's current content/thinking into the existing widgets in
     place. Used by the chat window between streaming deltas so we don't
     refreshMessages (and rebuild the entire pane) per token. When the
     thinking section appears mid-stream, instantiate its widgets and
     re-apply the layout so the new disclosure button/text show up."
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
        self replaceLayoutWith: self defaultLayout ]
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

{ #category : 'actions' }
SmallChatLMMessagePresenter >> toggleToolActivity [
	toolActivityVisible := self isToolActivityVisible not.
	self updateToolActivityWidget
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> toolActivity [
	^ toolActivity
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> toolActivity: aStringOrNil [
	"Attach a pre-formatted tool-activity summary for this assistant turn. The
	 window computes the text from the preceding tool_calls/tool-result messages
	 and pushes it onto the presenter via this setter so the layout can add the
	 toggle section. Passing nil or empty removes the toggle."
	toolActivity := aStringOrNil.
	self updateToolActivityWidget
]

{ #category : 'accessing' }
SmallChatLMMessagePresenter >> toolActivityToggleLabel [
	| glyph |
	glyph := self isToolActivityVisible
		ifTrue: [ self class expandedGlyph ]
		ifFalse: [ self class collapsedGlyph ].
	^ glyph , ' tool activity'
]

{ #category : 'private' }
SmallChatLMMessagePresenter >> updateThinkingWidget [
    "Re-apply the layout so the thinking body appears or disappears based on
     #isThinkingVisible. Spec2's replaceLayoutWith: no-ops when the presenter
     has no adapter (i.e. in unit tests where the presenter is never opened)."
    toggleButton isNil ifFalse: [ toggleButton label: self toggleLabel ].
    self replaceLayoutWith: self defaultLayout
]

{ #category : 'private' }
SmallChatLMMessagePresenter >> updateToolActivityWidget [
	"Instantiate / update the tool-activity toggle + body widgets to match the
	 current toolActivity value and visibility, then re-apply the layout. Mirrors
	 the thinking widget machinery."
	(self hasToolActivity and: [ toolActivityToggle isNil ]) ifTrue: [
		toolActivityToggle := self newButton
			label: self toolActivityToggleLabel;
			action: [ self toggleToolActivity ];
			yourself.
		toolActivityText := self newText
			beNotEditable;
			propagateNaturalHeight: true;
			text: (toolActivity ifNil: [ '' ]);
			yourself ].
	toolActivityToggle isNil ifFalse: [ toolActivityToggle label: self toolActivityToggleLabel ].
	toolActivityText isNil ifFalse: [ toolActivityText text: (toolActivity ifNil: [ '' ]) ].
	self replaceLayoutWith: self defaultLayout
]
