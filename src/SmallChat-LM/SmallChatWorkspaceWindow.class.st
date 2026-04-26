"
Spec2 window bound to one attached SmallChatTsWorkspace. The world-menu launcher pops a directory picker, attaches a TS workspace via SmallChatTsWorkspace>>attachAt:name:, mounts it on the SmallChatCapabilityRegistry, and opens this window. Closing the window detaches the workspace (registry unmount + ws shutdown).

Holds a chatPlaceholder presenter as the drop-in slot for a future workspace-scoped chat panel; the panel will be parameterised by a SmallChatLMSession whose tool dispatch stamps this workspace onto each call, and a SmallChatLMCapabilityCatalog filtered to the workspace kind.

Note: today the LSP launcher in SmallChatTsWorkspace defaults to nil, so attach is pure object construction and runs on the UI process. When real tsgo wiring lands, attach becomes blocking I/O and must move to a fork with status fed back via UIManager default defer:.
"
Class {
	#name : 'SmallChatWorkspaceWindow',
	#superclass : 'SpPresenter',
	#instVars : [
		'workspace',
		'headerLabel',
		'pathLabel',
		'statusLabel',
		'detachButton',
		'chatPlaceholder'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> chatPlaceholder [
	^ chatPlaceholder
]

{ #category : 'lifecycle' }
SmallChatWorkspaceWindow >> detachAndClose [
	"Stub for now -- slice 4 wires registry unmount + ws shutdown."
	^ self
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> detachButton [
	^ detachButton
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> headerLabel [
	^ headerLabel
]

{ #category : 'initialization' }
SmallChatWorkspaceWindow >> initializePresenters [
	headerLabel := self newLabel label: 'TS workspace'; yourself.
	pathLabel := self newLabel label: ''; yourself.
	statusLabel := self newLabel label: 'ready'; yourself.
	detachButton := self newButton
		label: 'Detach';
		action: [ self detachAndClose ];
		yourself.
	chatPlaceholder := self newPresenter.
	chatPlaceholder layout: SpBoxLayout newTopToBottom
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> pathLabel [
	^ pathLabel
]

{ #category : 'private' }
SmallChatWorkspaceWindow >> refreshFromWorkspace [
	"Update header/path labels from workspace. Called from workspace: setter
	 once presenters are initialized."
	workspace ifNil: [ ^ self ].
	headerLabel ifNotNil: [ headerLabel label: 'TS workspace: ' , workspace name ].
	pathLabel ifNotNil: [ pathLabel label: workspace path fullName ]
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> statusLabel [
	^ statusLabel
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> workspace [
	^ workspace
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> workspace: aWorkspace [
	workspace := aWorkspace.
	headerLabel isNil ifFalse: [ self refreshFromWorkspace ]
]
