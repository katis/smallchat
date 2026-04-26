"
Unit tests for SmallChatWorkspaceWindow.
"
Class {
	#name : 'SmallChatWorkspaceWindowTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'running' }
SmallChatWorkspaceWindowTest >> setUp [
	"Default tsgo launcher now spawns a real subprocess; these window tests only
	 need attachAt: to succeed without an LSP client. Install a nil-returning
	 stub for the duration of the test."
	super setUp.
	SmallChatTsWorkspace launcherBlock: [ :p | nil ]
]

{ #category : 'running' }
SmallChatWorkspaceWindowTest >> tearDown [
	SmallChatTsWorkspace resetLauncherBlock.
	super tearDown
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testAddSessionAppendsAndSelects [
  "addSession: appends to the window's sessions collection, makes the new
   session the selectedSession, and rebinds the chat panel so its session
   matches. This is the seam the future + button and the default-on-open
   path both go through."
  | window session |
  window := SmallChatWorkspaceWindow new.
  session := SmallChatLMSession new.
  window addSession: session.
  self assert: (window sessions includes: session).
  self assert: window selectedSession == session.
  self assert: window chatPlaceholder session == session
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testAttachOnPathAttachesAndMounts [
	| registry window prior |
	registry := SmallChatCapabilityRegistry new.
	prior := registry mountedWorkspaces size.
	window := SmallChatWorkspaceWindow new
		registryProvider: [ registry ];
		attachOnPath: '/tmp/smallchat-ws-attach' name: nil;
		yourself.
	self assert: window workspace notNil.
	self assert: (registry mountedWorkspaces includes: window workspace).
	self assert: registry mountedWorkspaces size = (prior + 1).
	self assert: window workspace path fullName = '/tmp/smallchat-ws-attach'.
	self assert: window workspace name = 'smallchat-ws-attach'
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testAttachOnPharoWorkspaceBindsDefaultPharoWorkspace [
	"The class-side launcher for the always-mounted Pharo workspace must
	 bind to SmallChatPharoWorkspace default (no fresh mount -- Pharo is
	 always in the registry) and install a chat panel scoped to it. The
	 LM then sees the full pharo capability set: eval/debug/vcs/workspace."
	| window panel session |
	window := SmallChatWorkspaceWindow new
		attachOnPharoWorkspace;
		yourself.
	self assert: window workspace == SmallChatPharoWorkspace default.
	panel := window chatPlaceholder.
	self assert: (panel isKindOf: SmallChatLMChatPanel).
	session := panel session.
	self assert: session workspace == SmallChatPharoWorkspace default.
	self assert: session client toolCatalog workspace == SmallChatPharoWorkspace default
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testAttachOnSamePathReusesMountedWorkspace [
	| registry w1 w2 prior |
	registry := SmallChatCapabilityRegistry new.
	prior := registry mountedWorkspaces size.
	w1 := SmallChatWorkspaceWindow new
		registryProvider: [ registry ];
		attachOnPath: '/tmp/smallchat-ws-idem' name: nil;
		yourself.
	w2 := SmallChatWorkspaceWindow new
		registryProvider: [ registry ];
		attachOnPath: '/tmp/smallchat-ws-idem' name: nil;
		yourself.
	self assert: w1 workspace == w2 workspace.
	self assert: registry mountedWorkspaces size = (prior + 1)
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testChatPlaceholderHostsPanelBoundToWorkspace [
	"After attachOnPath:name:, the chatPlaceholder slot is a
	 SmallChatLMChatPanel whose SmallChatLMSession is bound to the same
	 workspace the window is bound to. The panel's LM client carries a
	 catalog scoped to the same workspace, so the LM only sees tools that
	 fit its kind."
	| registry window panel session |
	registry := SmallChatCapabilityRegistry new.
	window := SmallChatWorkspaceWindow new
		registryProvider: [ registry ];
		attachOnPath: '/tmp/smallchat-ws-panel' name: nil;
		yourself.
	panel := window chatPlaceholder.
	self assert: (panel isKindOf: SmallChatLMChatPanel).
	session := panel session.
	self assert: session notNil.
	self assert: session workspace == window workspace.
	self assert: session client toolCatalog workspace == window workspace
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testDefaultLayoutContainsOnlyChatPlaceholder [
	| ws window children |
	ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-ws-fixture' name: 'fixture-ws'.
	window := SmallChatWorkspaceWindow new workspace: ws; yourself.
	children := window defaultLayout children.
	self assert: children size = 1.
	self assert: (children includes: window chatPlaceholder)
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testDetachAndCloseUnmountsAndShutsDownIdempotent [
	| registry ws window |
	registry := SmallChatCapabilityRegistry new.
	ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-ws-detach' name: 'detach-ws'.
	ws lspClient: 'sentinel'.
	registry mountWorkspace: ws.
	window := SmallChatWorkspaceWindow new
		registryProvider: [ registry ];
		workspace: ws;
		yourself.
	window detachAndClose.
	self assert: (registry mountedWorkspaces includes: ws) not.
	self assert: ws lspClient isNil.
	"Second call must not raise."
	[ window detachAndClose ] on: Error do: [ :e | self fail: 'detachAndClose should be idempotent: ' , e messageText ]
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testDirectoryPickerBlockSeamReturnsConfiguredValue [
	| sentinel result |
	sentinel := '/tmp/smallchat-ws-picked' asFileReference.
	SmallChatWorkspaceWindow directoryPickerBlock: [ sentinel ].
	[ result := SmallChatWorkspaceWindow pickDirectory ]
		ensure: [ SmallChatWorkspaceWindow resetDirectoryPickerBlock ].
	self assert: result == sentinel
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testInitializePresentersBuildsChatPlaceholder [
	| ws window |
	ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-ws-fixture' name: 'fixture-ws'.
	window := SmallChatWorkspaceWindow new
		workspace: ws;
		yourself.
	self assert: window chatPlaceholder notNil.
	self assert: (window chatPlaceholder isKindOf: SpPresenter)
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testWindowTitleForPharoWorkspaceUsesName [
	| window title |
	window := SmallChatWorkspaceWindow new
		workspace: SmallChatPharoWorkspace default;
		yourself.
	title := window windowTitle.
	self assert: (title includesSubstring: 'pharo')
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testWindowTitleForTsWorkspaceIncludesNameAndPath [
	| ws window title |
	ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-ws-title' name: 'title-ws'.
	window := SmallChatWorkspaceWindow new workspace: ws; yourself.
	title := window windowTitle.
	self assert: (title includesSubstring: 'title-ws').
	self assert: (title includesSubstring: '/tmp/smallchat-ws-title')
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testWorkspaceAccessorRoundTrip [
	| ws window |
	ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-ws-fixture' name: 'fixture-ws'.
	window := SmallChatWorkspaceWindow new.
	window workspace: ws.
	self assert: window workspace == ws
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testWorldMenuExposesPharoWorkspaceLauncher [
	"There must be a <worldMenu> entry that opens a Pharo-flavoured
	 workspace window. Verified by enumerating menu items the way
	 PragmaMenuBuilder would assemble them."
	| builder labels hasPharoEntry |
	builder := PragmaMenuBuilder pragmaKeyword: #worldMenu model: Object new.
	SmallChatWorkspaceWindow class methods do: [ :m |
		(m pragmas anySatisfy: [ :p | p selector = #worldMenu ]) ifTrue: [
			SmallChatWorkspaceWindow perform: m selector with: builder ] ].
	labels := builder itemList collect: [ :item | item name asString ].
	hasPharoEntry := labels anySatisfy: [ :l | l asLowercase includesSubstring: 'pharo' ].
	self assert: hasPharoEntry description: 'world menu must include a Pharo-workspace launcher; got: ' , labels printString
]
