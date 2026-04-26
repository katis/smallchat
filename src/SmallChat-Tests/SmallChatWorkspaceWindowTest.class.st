"
Unit tests for SmallChatWorkspaceWindow.
"
Class {
	#name : 'SmallChatWorkspaceWindowTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'helpers' }
SmallChatWorkspaceWindowTest >> assertCenter: aForm closeTo: aColor [
  "Form rendering quantises 8-bit channels so the centre pixel of a dot
   drawn with aColor differs by ~0.001 -- assert RGB channels match within
   a tolerance instead of exact equality, which would couple the test to
   sRGB rounding choices that are not the contract."
  | actual tolerance |
  actual := aForm colorAt: 6@6.
  tolerance := 0.02.
  self assert: (actual red - aColor red) abs < tolerance description: 'red channel off'.
  self assert: (actual green - aColor green) abs < tolerance description: 'green channel off'.
  self assert: (actual blue - aColor blue) abs < tolerance description: 'blue channel off'.
  self assert: actual alpha equals: 1.0
]

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
SmallChatWorkspaceWindowTest >> testAddSessionShowsRowAndSelects [
  "Each addSession: drops the new session into the agent tree's roots and
   makes it the selected row. Adding two sessions in sequence leaves both
   visible with the most recent one selected -- selection follows the
   creation that just happened."
  | window a b |
  window := SmallChatWorkspaceWindow new.
  a := SmallChatLMSession new.
  b := SmallChatLMSession new.
  window addSession: a.
  window addSession: b.
  self assert: window agentTree roots asArray equals: { a. b }.
  self assert: window agentTree selectedItem == b
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testAgentTreeRendersStatusColumnAndNameColumn [
  "The tree has two columns: a status icon on the left, then the name.
   The icon column reads through SmallChatWorkspaceWindow class>>dotFormFor:
   so a session's status flips its dot when the row is re-evaluated."
  | window session iconColumn nameColumn |
  window := SmallChatWorkspaceWindow new.
  self assert: window agentTree columns size equals: 2.
  iconColumn := window agentTree columns first.
  nameColumn := window agentTree columns second.
  self assert: (iconColumn isKindOf: SpImageTableColumn).
  self assert: (nameColumn isKindOf: SpStringTableColumn).
  session := SmallChatLMSession new name: 'Tester'; yourself.
  session status: #running.
  self assert: (iconColumn evaluation value: session) class equals: Form.
  self assert: (nameColumn evaluation value: session) equals: 'Tester'
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
SmallChatWorkspaceWindowTest >> testAttachSeedsDefaultSession [
  "Opening a window seeds one session built from the first profile in
   the registry so the right pane is never blank. The profileRegistry
   is a block test seam (default reads SmallChatAgentProfile all) so
   the test can pin the seeded profile without mutating global state."
  | picked window |
  picked := SmallChatAgentProfile new
    name: 'Stub';
    modelName: SmallChatAgentProfile availableModels first;
    systemPrompt: 'stub-prompt';
    yourself.
  window := SmallChatWorkspaceWindow new
    profileRegistry: [ { picked } ];
    attachOnPharoWorkspace;
    yourself.
  self assert: window sessions size equals: 1.
  self assert: window selectedSession profile == picked.
  self assert: window selectedSession name equals: 'Stub'
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testBuildsHeadlessly [
  "End-to-end smoke that the window can be constructed in the headless
   reader process without opening a Morphic window or attaching a
   workspace. All key presenters must be wired and the layout must be
   the paned shape this feature introduced."
  | window |
  window := SmallChatWorkspaceWindow new.
  self assert: window agentTree notNil.
  self assert: window chatPlaceholder notNil.
  self assert: window addButton notNil.
  self assert: (window defaultLayout isKindOf: SpPanedLayout).
  self assert: window sessions isEmpty
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
SmallChatWorkspaceWindowTest >> testCleanupCancelsEverySession [
  "windowDidClose must walk every session in the window and call
   cancelInFlight on each so a slow capability driven by an unselected
   session can't outlive the UI it was driving. Verified by giving each
   session a long-running worker process and asserting both are
   terminated after windowDidClose runs."
  | window s1 s2 w1 w2 |
  window := SmallChatWorkspaceWindow new.
  s1 := SmallChatLMSession new.
  s2 := SmallChatLMSession new.
  w1 := [ (Delay forSeconds: 60) wait ] newProcess.
  w2 := [ (Delay forSeconds: 60) wait ] newProcess.
  s1 trackInFlight: w1. w1 resume.
  s2 trackInFlight: w2. w2 resume.
  window addSession: s1.
  window addSession: s2.
  window windowDidClose.
  self assert: w1 isTerminated.
  self assert: w2 isTerminated
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testCreateSessionFromChooserUsesInjectedBlock [
  "createSessionFromChooser asks the injected profileChooser block for a
   profile, builds a session via SmallChatLMSession profile:workspace:,
   and adds it to the window. The block is the test seam; the default
   pops a UIManager modal which would deadlock under the headless
   reader."
  | window picked |
  window := SmallChatWorkspaceWindow new
    workspace: SmallChatPharoWorkspace default;
    profileChooser: [ :profiles | profiles first ];
    yourself.
  window createSessionFromChooser.
  picked := SmallChatAgentProfile all first.
  self assert: window sessions size equals: 1.
  self assert: window selectedSession profile == picked.
  self assert: window selectedSession name equals: picked name
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testDefaultLayoutIsPanedWithChatPlaceholderOnRight [
  "After the agent-tree refactor the top-level layout is a horizontal
   SpPanedLayout. The chat placeholder is a direct child (right pane);
   the agent tree lives inside the left-pane box layout."
  | ws window layout topChildren leftChildren |
  ws := SmallChatTsWorkspace attachAt: '/tmp/smallchat-ws-fixture' name: 'fixture-ws'.
  window := SmallChatWorkspaceWindow new workspace: ws; yourself.
  layout := window defaultLayout.
  self assert: (layout isKindOf: SpPanedLayout).
  topChildren := layout children.
  self assert: (topChildren includes: window chatPlaceholder).
  leftChildren := (topChildren detect: [ :c | c isKindOf: SpBoxLayout ]) children.
  self assert: (leftChildren includes: window agentTree).
  self assert: (leftChildren includes: window addButton)
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
SmallChatWorkspaceWindowTest >> testDotFormForAwaitingHasAmberCenter [
  "#awaiting renders as a solid amber/orange dot."
  | f |
  f := SmallChatWorkspaceWindow dotFormFor: #awaiting.
  self assertCenter: f closeTo: Color orange
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testDotFormForCancelledHasGreyCenter [
  "#cancelled renders as a solid grey dot, distinct from the hollow #idle ring."
  | f |
  f := SmallChatWorkspaceWindow dotFormFor: #cancelled.
  self assertCenter: f closeTo: Color gray
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testDotFormForErroredHasRedCenter [
  "#errored renders as a solid red dot."
  | f |
  f := SmallChatWorkspaceWindow dotFormFor: #errored.
  self assertCenter: f closeTo: Color red
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testDotFormForIdleHasTransparentCenter [
  "#idle renders as a hollow ring -- the centre pixel is transparent so
   the row background shows through. Pinned at the centre to survive
   palette tweaks; the rim of the ring is rendered separately."
  | f |
  f := SmallChatWorkspaceWindow dotFormFor: #idle.
  self assert: (f colorAt: 6@6) isTransparent
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testDotFormForRunningHasGreenCenter [
  "#running renders as a solid green dot."
  | f |
  f := SmallChatWorkspaceWindow dotFormFor: #running.
  self assertCenter: f closeTo: Color green
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testDotFormForUnknownFallsBackToIdle [
  "Unknown symbols fall back to the #idle hollow form so a future state
   added to the session domain does not crash the tree before the helper
   is updated."
  | f |
  f := SmallChatWorkspaceWindow dotFormFor: #unknownSymbol.
  self assert: (f colorAt: 6@6) isTransparent
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
SmallChatWorkspaceWindowTest >> testLayoutHasAgentTreeAndPaned [
  "The window's top-level layout is a horizontal SpPanedLayout with the
   agent tree on the left (empty by default) and the chat placeholder on
   the right. Verified by inspecting the layout class and the agentTree
   presenter; we don't open a window."
  | window |
  window := SmallChatWorkspaceWindow new.
  self assert: (window agentTree isKindOf: SpTreeTablePresenter).
  self assert: window agentTree roots isEmpty.
  self assert: (window defaultLayout isKindOf: SpPanedLayout)
]

{ #category : 'tests' }
SmallChatWorkspaceWindowTest >> testTreeSelectionDrivesChatPanel [
  "Selecting a different row in the agent tree must rebind the chat
   panel's session and update the window's selectedSession so the
   right pane shows the chat for the picked row."
  | window a b |
  window := SmallChatWorkspaceWindow new.
  a := SmallChatLMSession new.
  b := SmallChatLMSession new.
  window addSession: a.
  window addSession: b.
  window agentTree selectItem: a.
  self assert: window selectedSession == a.
  self assert: window chatPlaceholder session == a
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
