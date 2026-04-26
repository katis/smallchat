Class {
	#name : 'SmallChatAgentProfileWindowTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatAgentProfileWindowTest >> testAddNewProfileSelectsNewDraft [
	"Add appends a new profile with a unique generated name, refreshes the
	 list, and selects the freshly-added row so the user can immediately
	 edit its fields."
	| win before after newRow |
	SmallChatAgentProfile reset.
	win := SmallChatAgentProfileWindow new.
	before := SmallChatAgentProfile all size.
	win addNewProfile.
	after := SmallChatAgentProfile all size.
	self assert: after equals: before + 1.
	newRow := win profileList selectedItem.
	self assert: newRow notNil.
	self assert: (win profileList items includes: newRow).
	self assert: (newRow name beginsWith: 'New profile')
]

{ #category : 'tests' }
SmallChatAgentProfileWindowTest >> testProfileSelectedPopulatesFields [
	"Selecting a profile copies its fields into the editor inputs so the
	 user sees its current state."
	| win profile |
	SmallChatAgentProfile reset.
	profile := SmallChatAgentProfile new
		name: 'select-fixture';
		modelName: 'Qwen3.6-27B-MLX-8bit';
		systemPrompt: 'select-prompt';
		yourself.
	SmallChatAgentProfile add: profile.
	win := SmallChatAgentProfileWindow new.
	win refreshProfileList.
	win profileSelected: profile.
	self assert: win nameInput text equals: 'select-fixture'.
	self assert: win promptText text equals: 'select-prompt'.
	self assert: win modelDropList selectedItem equals: 'Qwen3.6-27B-MLX-8bit'.
	self assert: win currentProfile == profile
]

{ #category : 'tests' }
SmallChatAgentProfileWindowTest >> testSaveWritesFormFieldsBack [
	"Save flushes the editor inputs into the currently-selected profile,
	 refreshes the list, and keeps the selection on the (possibly renamed)
	 row so the user keeps their place."
	| win profile |
	SmallChatAgentProfile reset.
	profile := SmallChatAgentProfile new
		name: 'save-orig';
		modelName: 'Qwen3.6-27B-MLX-8bit';
		systemPrompt: 'orig prompt';
		yourself.
	SmallChatAgentProfile add: profile.
	win := SmallChatAgentProfileWindow new.
	win refreshProfileList.
	win profileSelected: profile.
	win nameInput text: 'save-renamed'.
	win modelDropList selectItem: 'Qwen3.6-35B-A3B-nvfp4'.
	win promptText text: 'renamed prompt'.
	win saveCurrentProfile.
	self assert: profile name equals: 'save-renamed'.
	self assert: profile modelName equals: 'Qwen3.6-35B-A3B-nvfp4'.
	self assert: profile systemPrompt equals: 'renamed prompt'.
	self assert: (SmallChatAgentProfile named: 'save-renamed') == profile.
	self assert: win profileList selectedItem == profile
]

{ #category : 'tests' }
SmallChatAgentProfileWindowTest >> testWindowBuildsAndShowsDefault [
	"A new window has all four editor presenters wired up, and its profile
	 list reflects the registry -- so a fresh image opens to the seeded
	 Default agent ready for inspection."
	| win listed |
	SmallChatAgentProfile reset.
	win := SmallChatAgentProfileWindow new.
	self assert: win profileList notNil.
	self assert: win nameInput notNil.
	self assert: win modelDropList notNil.
	self assert: win promptText notNil.
	listed := win profileList items collect: [ :p | p name ].
	self assert: (listed includes: 'Default')
]
