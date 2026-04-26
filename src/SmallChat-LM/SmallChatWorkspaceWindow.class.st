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
		'chatPlaceholder',
		'registryProvider'
	],
	#classInstVars : [
		'directoryPickerBlock'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'picker' }
SmallChatWorkspaceWindow class >> directoryPickerBlock [
	"Block that returns a directory FileReference (or nil if cancelled).
	 Test seam: tests swap to a block returning a known FileReference.
	 Default uses Pharo's native chooseDirectory: dialog."
	^ directoryPickerBlock
		ifNil: [ [ UIManager default chooseDirectory: 'Pick a TS workspace directory' ] ]
]

{ #category : 'picker' }
SmallChatWorkspaceWindow class >> directoryPickerBlock: aBlock [
	directoryPickerBlock := aBlock
]

{ #category : 'world menu' }
SmallChatWorkspaceWindow class >> menuCommandOn: aBuilder [
	<worldMenu>
	(aBuilder item: #'smallchat workspace')
		parent: #Tools;
		order: 101;
		help: 'Pick a directory and open a TS workspace window';
		icon: (self iconNamed: #smallNew);
		action: [ UIManager default defer: [ self open ] ]
]

{ #category : 'opening' }
SmallChatWorkspaceWindow class >> open [
	"Pop the directory picker; if the user chose a directory, attach + open
	 a workspace window for it. Returns the new window or nil if cancelled."
	| dir |
	dir := self pickDirectory.
	dir ifNil: [ ^ nil ].
	^ self openOnPath: dir fullName name: nil
]

{ #category : 'opening' }
SmallChatWorkspaceWindow class >> openOnPath: aPath name: aNameOrNil [
	"Build a workspace window for aPath, mount it, and open. Returns the
	 window. aPath may be a String or FileReference -- canonicalisation
	 happens inside attachOnPath:name:."
	^ self new
		attachOnPath: aPath name: aNameOrNil;
		open;
		yourself
]

{ #category : 'picker' }
SmallChatWorkspaceWindow class >> pickDirectory [
	"Pop the directory picker. Returns the FileReference the user chose,
	 or nil if they cancelled."
	^ self directoryPickerBlock value
]

{ #category : 'picker' }
SmallChatWorkspaceWindow class >> resetDirectoryPickerBlock [
	directoryPickerBlock := nil
]

{ #category : 'lifecycle' }
SmallChatWorkspaceWindow >> attachOnPath: aPath name: aNameOrNil [
	"Resolve aPath, attach a SmallChatTsWorkspace if not already mounted,
	 mount it on this window's registry, bind it, and replace the chat
	 placeholder with a SmallChatLMChatPanel scoped to the bound workspace.
	 Returns self for chaining. Idempotent on canonical path -- a second
	 call with the same path reuses the existing mount."
	| registry ref existing ws |
	registry := self registry.
	ref := SmallChatTsWorkspace canonicalise: aPath.
	existing := registry mountedWorkspaceForPath: ref.
	ws := existing
		ifNil: [
			| fresh |
			fresh := SmallChatTsWorkspace attachAt: aPath name: aNameOrNil.
			registry mountWorkspace: fresh.
			fresh ]
		ifNotNil: [ existing ].
	self workspace: ws.
	self installChatPanelFor: ws.
	^ self
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> chatPlaceholder [
	^ chatPlaceholder
]

{ #category : 'layout' }
SmallChatWorkspaceWindow >> defaultLayout [
	^ SpBoxLayout newTopToBottom
		spacing: 4;
		add: headerLabel expand: false;
		add: pathLabel expand: false;
		add: statusLabel expand: false;
		add: detachButton expand: false;
		add: chatPlaceholder;
		yourself
]

{ #category : 'lifecycle' }
SmallChatWorkspaceWindow >> detachAndClose [
	"Unmount the bound workspace from the registry and shut its LSP client
	 down. Idempotent: the second call sees a nil workspace and exits cleanly."
	workspace ifNil: [ ^ self ].
	self registry unmountWorkspace: workspace.
	workspace shutdown.
	workspace := nil
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

{ #category : 'initialization' }
SmallChatWorkspaceWindow >> initializeWindow: aWindow [
	"Title is the workspace name (set after #workspace: lands). whenClosedDo:
	 first cleans up the chat panel (drops the MCP-announcer subscription,
	 terminates any in-flight reply fork) and then unmounts the bound
	 workspace via the registry and shuts its LSP client down. Both
	 cleanups are idempotent so a second close is safe."
	| title |
	title := workspace
		ifNil: [ 'smallchat workspace' ]
		ifNotNil: [ 'smallchat / ' , workspace name ].
	aWindow
		title: title;
		initialExtent: 480 @ 360;
		whenClosedDo: [
			(chatPlaceholder respondsTo: #cleanup) ifTrue: [ chatPlaceholder cleanup ].
			self detachAndClose ]
]

{ #category : 'private' }
SmallChatWorkspaceWindow >> installChatPanelFor: aWorkspace [
	"Replace chatPlaceholder with a SmallChatLMChatPanel whose session is
	 bound to aWorkspace. Spec2 instantiate: wires sub-presenter ownership
	 so the panel renders inside the window. Called from attach paths once
	 the workspace is known."
	| panel session |
	panel := self instantiate: SmallChatLMChatPanel.
	session := SmallChatLMSession new workspace: aWorkspace; yourself.
	panel session: session.
	chatPlaceholder := panel
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
SmallChatWorkspaceWindow >> registry [
	"The capability registry this window dispatches against. Test seam:
	 #registryProvider: lets a fresh registry be injected; defaults to the
	 system-wide singleton."
	^ registryProvider
		ifNil: [ SmallChatCapabilityRegistry default ]
		ifNotNil: [ registryProvider value ]
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> registryProvider: aBlock [
	registryProvider := aBlock
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
