"
Spec2 window bound to one workspace -- either an attached SmallChatTsWorkspace (via attachOnPath:name: + a directory picker) or the always-mounted SmallChatPharoWorkspace (via attachOnPharoWorkspace). Closing the window cleans up the embedded chat panel and detaches the workspace (registry unmount + ws shutdown for TS; nothing to unmount for Pharo).

The chatPlaceholder slot is filled with a SmallChatLMChatPanel parameterised by a SmallChatLMSession bound to the window's workspace; the session stamps that workspace onto every tool call and the panel's LM client carries a SmallChatLMCapabilityCatalog filtered to the workspace kind. Result: each window's chat sees only the tools that fit its workspace.

Note: today the LSP launcher in SmallChatTsWorkspace defaults to nil, so attach is pure object construction and runs on the UI process. When real tsgo wiring lands, attach becomes blocking I/O and must move to a fork with status fed back via UIManager default defer:.
"
Class {
	#name : 'SmallChatWorkspaceWindow',
	#superclass : 'SpPresenter',
	#instVars : [
		'workspace',
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

{ #category : 'opening' }
SmallChatWorkspaceWindow class >> openOnPharoWorkspace [
	"Build a workspace window bound to the always-mounted Pharo workspace
	 and open it. Used by the world-menu launcher and by callers that want
	 to chat with the live image (eval/debug/vcs tools all available)."
	^ self new
		attachOnPharoWorkspace;
		open;
		yourself
]

{ #category : 'world menu' }
SmallChatWorkspaceWindow class >> pharoWorkspaceMenuCommandOn: aBuilder [
	<worldMenu>
	(aBuilder item: #'smallchat pharo image')
		parent: #Tools;
		order: 102;
		help: 'Open a workspace window bound to the always-mounted Pharo workspace';
		icon: (self iconNamed: #smallConfiguration);
		action: [ UIManager default defer: [ self openOnPharoWorkspace ] ]
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

{ #category : 'lifecycle' }
SmallChatWorkspaceWindow >> attachOnPharoWorkspace [
	"Bind this window to the always-mounted Pharo workspace and install a
	 chat panel scoped to it. No registry mount is needed -- Pharo is in
	 mountedWorkspaces from registry construction. Returns self for
	 chaining."
	| ws |
	ws := SmallChatPharoWorkspace default.
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

{ #category : 'initialization' }
SmallChatWorkspaceWindow >> initializePresenters [
	chatPlaceholder := self newPresenter.
	chatPlaceholder layout: SpBoxLayout newTopToBottom
]

{ #category : 'initialization' }
SmallChatWorkspaceWindow >> initializeWindow: aWindow [
	"whenClosedDo: cleans up the chat panel (drops the MCP-announcer
	 subscription, terminates any in-flight reply fork) and unmounts the
	 bound workspace via the registry. Both cleanups are idempotent so a
	 second close is safe."
	aWindow
		title: self windowTitle;
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
SmallChatWorkspaceWindow >> windowTitle [
	"Compose the window title from the bound workspace. TS workspaces
	 carry a filesystem path; Pharo-flavoured ones do not."
	workspace ifNil: [ ^ 'smallchat workspace' ].
	^ (workspace respondsTo: #path)
		ifTrue: [ 'smallchat / ' , workspace name , ' (' , workspace path fullName , ')' ]
		ifFalse: [ 'smallchat / ' , workspace name ]
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> workspace [
	^ workspace
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> workspace: aWorkspace [
	workspace := aWorkspace
]
