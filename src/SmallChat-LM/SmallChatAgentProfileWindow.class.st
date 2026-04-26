Class {
	#name : 'SmallChatAgentProfileWindow',
	#superclass : 'SpPresenter',
	#instVars : [
		'profileList',
		'nameInput',
		'modelDropList',
		'promptText',
		'addButton',
		'deleteButton',
		'saveButton',
		'currentProfile'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatAgentProfileWindow >> addButton [
	^ addButton
]

{ #category : 'actions' }
SmallChatAgentProfileWindow >> addNewProfile [
	"Add a fresh profile with a unique generated name, refresh the list,
	 and select the new row so the editor fields populate from it."
	| profile |
	profile := SmallChatAgentProfile new
		name: self uniqueDraftName;
		yourself.
	SmallChatAgentProfile add: profile.
	self refreshProfileList.
	profileList selectItem: profile
]

{ #category : 'accessing' }
SmallChatAgentProfileWindow >> currentProfile [
	^ currentProfile
]

{ #category : 'layout' }
SmallChatAgentProfileWindow >> defaultLayout [
	"Master/detail box layout: profile list on the left with Add/Delete
	 below, single-profile editor on the right (name input, model
	 drop-list, prompt text area, Save button)."
	^ SpBoxLayout newLeftToRight
		spacing: 6;
		add: (SpBoxLayout newTopToBottom
				spacing: 4;
				add: profileList;
				add: (SpBoxLayout newLeftToRight
						spacing: 4;
						add: addButton;
						add: deleteButton;
						yourself) expand: false;
				yourself) width: 240;
		add: (SpBoxLayout newTopToBottom
				spacing: 4;
				add: (SpBoxLayout newLeftToRight
						spacing: 4;
						add: (self newLabel label: 'Name') expand: false;
						add: nameInput;
						yourself) expand: false;
				add: (SpBoxLayout newLeftToRight
						spacing: 4;
						add: (self newLabel label: 'Model') expand: false;
						add: modelDropList;
						yourself) expand: false;
				add: (self newLabel label: 'System prompt') expand: false;
				add: promptText;
				add: (SpBoxLayout newLeftToRight
						addLast: saveButton;
						yourself) expand: false;
				yourself);
		yourself
]

{ #category : 'accessing' }
SmallChatAgentProfileWindow >> deleteButton [
	^ deleteButton
]

{ #category : 'actions' }
SmallChatAgentProfileWindow >> deleteSelectedProfile [
	"Slice 12."
	^ self
]

{ #category : 'initialization' }
SmallChatAgentProfileWindow >> initializePresenters [
	"Master/detail editor: list of profiles on the left, single-profile
	 editor (name, model, system prompt) on the right. Fields stay empty
	 until a row is selected -- selection populates them, Save writes back."
	profileList := self newList
		display: [ :p | p name ifNil: [ '(unnamed)' ] ];
		yourself.
	profileList whenSelectionChangedDo: [ :sel | self profileSelected: sel selectedItem ].
	nameInput := self newTextInput
		placeholder: 'profile name';
		yourself.
	modelDropList := self newDropList.
	modelDropList items: SmallChatAgentProfile availableModels.
	promptText := self newText.
	addButton := self newButton
		label: 'Add';
		action: [ self addNewProfile ];
		yourself.
	deleteButton := self newButton
		label: 'Delete';
		action: [ self deleteSelectedProfile ];
		yourself.
	saveButton := self newButton
		label: 'Save';
		action: [ self saveCurrentProfile ];
		yourself.
	self refreshProfileList
]

{ #category : 'initialization' }
SmallChatAgentProfileWindow >> initializeWindow: aWindowPresenter [
	aWindowPresenter
		title: 'SmallChat agent profiles';
		initialExtent: 720 @ 480
]

{ #category : 'accessing' }
SmallChatAgentProfileWindow >> modelDropList [
	^ modelDropList
]

{ #category : 'accessing' }
SmallChatAgentProfileWindow >> nameInput [
	^ nameInput
]

{ #category : 'accessing' }
SmallChatAgentProfileWindow >> profileList [
	^ profileList
]

{ #category : 'private' }
SmallChatAgentProfileWindow >> profileSelected: aProfileOrNil [
	"Populate the editor fields from aProfileOrNil. nil clears them."
	currentProfile := aProfileOrNil.
	aProfileOrNil
		ifNil: [
			nameInput text: ''.
			promptText text: ''.
			modelDropList selectItem: SmallChatAgentProfile availableModels first ]
		ifNotNil: [
			nameInput text: (aProfileOrNil name ifNil: [ '' ]).
			promptText text: (aProfileOrNil systemPrompt ifNil: [ '' ]).
			modelDropList selectItem: aProfileOrNil modelName ]
]

{ #category : 'accessing' }
SmallChatAgentProfileWindow >> promptText [
	^ promptText
]

{ #category : 'private' }
SmallChatAgentProfileWindow >> refreshProfileList [
	"Reload the list from the registry, preserving selection by name when
	 the previously-selected profile is still present."
	| previousName items selected |
	previousName := profileList selectedItem ifNotNil: [ :p | p name ].
	items := SmallChatAgentProfile all.
	profileList items: items.
	selected := previousName
		ifNotNil: [ items detect: [ :p | p name = previousName ] ifNone: [ nil ] ].
	selected ifNotNil: [ profileList selectItem: selected ]
]

{ #category : 'accessing' }
SmallChatAgentProfileWindow >> saveButton [
	^ saveButton
]

{ #category : 'actions' }
SmallChatAgentProfileWindow >> saveCurrentProfile [
	"Flush editor inputs into the currently-selected profile through its
	 validating setters, then refresh the list and reselect the row.
	 Captures the profile in a local first because refreshProfileList's
	 items: fires whenSelectionChangedDo:, which nils currentProfile via
	 profileSelected:. Validation errors surface as a deferred dialog
	 rather than raising -- this method may be invoked from the MCP reader
	 where a raise would corrupt JSON-RPC framing."
	| profile |
	profile := currentProfile.
	profile ifNil: [ ^ self ].
	[ profile name: nameInput text.
	  profile modelName: modelDropList selectedItem.
	  profile systemPrompt: promptText text ]
		on: Error
		do: [ :ex |
			UIManager default defer: [ self inform: ex messageText ].
			^ self ].
	self refreshProfileList.
	profileList selectItem: profile
]

{ #category : 'private' }
SmallChatAgentProfileWindow >> uniqueDraftName [
	"Return the first 'New profile', 'New profile 2', 'New profile 3' ...
	 not currently in the registry."
	| base index candidate taken |
	base := 'New profile'.
	taken := SmallChatAgentProfile all collect: [ :p | p name ].
	(taken includes: base) ifFalse: [ ^ base ].
	index := 2.
	[ candidate := base , ' ' , index printString.
	  taken includes: candidate ]
		whileTrue: [ index := index + 1 ].
	^ candidate
]
