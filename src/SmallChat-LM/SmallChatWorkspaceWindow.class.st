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
		'registryProvider',
		'sessions',
		'selectedSession',
		'agentTree',
		'addButton'
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

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> addButton [
  ^ addButton
]

{ #category : 'sessions' }
SmallChatWorkspaceWindow >> addSession: aSession [
  "Append aSession to the window's in-memory collection, refresh the
   agent tree's roots so the new row appears, and select it. The
   selection wiring in initializePresenters then routes back through
   selectSession: to rebind the chat panel."
  self sessions add: aSession.
  agentTree
    roots: self sessions asArray;
    selectItem: aSession.
  self selectSession: aSession
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> agentTree [
  ^ agentTree
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
  "Horizontal paned layout: the agent tree (and its + button) live on the
   left, the chat placeholder on the right. The tree is the selection
   surface; the placeholder swaps its bound session as the selection
   changes."
  ^ SpPanedLayout newHorizontal
    positionOfSlider: 240;
    add: (SpBoxLayout newTopToBottom
      spacing: 4;
      add: addButton expand: false;
      add: agentTree;
      yourself);
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

{ #category : 'private' }
SmallChatWorkspaceWindow >> ensureChatPanel [
  "Build the SmallChatLMChatPanel sub-presenter on first use and cache it
   in chatPlaceholder. selectSession: drives this so the panel is created
   lazily -- a bare SpPresenter sits there until a session is bound."
  (chatPlaceholder isKindOf: SmallChatLMChatPanel)
    ifTrue: [ ^ chatPlaceholder ].
  chatPlaceholder := self instantiate: SmallChatLMChatPanel.
  ^ chatPlaceholder
]

{ #category : 'initialization' }
SmallChatWorkspaceWindow >> initializePresenters [
  "Build the bare presenters: an empty SpPresenter as the chat slot (lazily
   replaced with a SmallChatLMChatPanel by ensureChatPanel), the agent tree
   on the left wired to drive selectSession: on selection-change, and the
   + button above the tree."
  chatPlaceholder := self newPresenter.
  chatPlaceholder layout: SpBoxLayout newTopToBottom.
  agentTree := self newTreeTable.
  agentTree
    addColumn: (SpStringTableColumn new
      title: 'Agent';
      evaluated: [ :s | s name ifNil: [ '' ] ];
      yourself);
    children: [ :s | #() ];
    roots: #();
    whenSelectionChangedDo: [ :sel |
      sel selectedItem ifNotNil: [ :s | self selectSession: s ] ].
  addButton := self newButton
    label: '+';
    yourself
]

{ #category : 'initialization' }
SmallChatWorkspaceWindow >> initializeWindow: aWindow [
  "whenClosedDo: routes through windowDidClose so the per-window
   teardown (cancel-all-sessions, panel cleanup, workspace unmount) is
   testable without opening a real window."
  aWindow
    title: self windowTitle;
    initialExtent: 480 @ 360;
    whenClosedDo: [ self windowDidClose ]
]

{ #category : 'private' }
SmallChatWorkspaceWindow >> installChatPanelFor: aWorkspace [
  "Bridge for the existing attach paths: build a session bound to
   aWorkspace and route it through #addSession: so the new sessions
   collection stays in sync. Slice 11 will move session construction
   out to the attach call sites with profile injection."
  self addSession: (SmallChatLMSession new workspace: aWorkspace; yourself)
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

{ #category : 'sessions' }
SmallChatWorkspaceWindow >> selectSession: aSession [
  "Mark aSession as the visible session and rebind the chat panel's session
   to it. Idempotent: re-selecting the current session is a no-op."
  selectedSession == aSession ifTrue: [ ^ self ].
  selectedSession := aSession.
  self ensureChatPanel session: aSession
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> selectedSession [
  ^ selectedSession
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> sessions [
  ^ sessions ifNil: [ sessions := OrderedCollection new ]
]

{ #category : 'lifecycle' }
SmallChatWorkspaceWindow >> windowDidClose [
  "Tear down per-window external bindings. Walks every session calling
   cancelInFlight (the panel's own #cleanup only knows about the
   selected one) so background workers on unselected sessions don't
   outlive the window. Then drops the panel's subscriptions and
   unmounts the bound workspace. All steps idempotent so a second call
   is safe."
  self sessions do: [ :s |
    [ s cancelInFlight ] on: Error do: [ :_ | "best-effort cancel" ] ].
  (chatPlaceholder respondsTo: #cleanup) ifTrue: [ chatPlaceholder cleanup ].
  self detachAndClose
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
