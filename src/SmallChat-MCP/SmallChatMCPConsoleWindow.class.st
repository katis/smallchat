"
Tabbed window inspecting live MCP traffic. One SpNotebookPage per
SmallChatMCPConnection on the bound SmallChatMCPTcpServer; each tab
embeds a SmallChatMCPConnectionPanel pre-bound to the connection and
the server's announcer.

Tabs persist after the underlying connection closes -- the title
gains a ``(closed)`` marker but the panel and its call records stay
inspectable until the console window itself is closed.

Reachable from the World menu (``Tools > smallchat mcp console``)
or programmatically via SmallChatMCPConsoleWindow open. Closing the
window unsubscribes the announcer and cascades cleanup to each panel.
"
Class {
	#name : 'SmallChatMCPConsoleWindow',
	#superclass : 'SpPresenter',
	#instVars : [
		'notebook',
		'server',
		'panelsByConnection',
		'uiDeferrer'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'world menu' }
SmallChatMCPConsoleWindow class >> consoleMenuCommandOn: aBuilder [
    <worldMenu>
    (aBuilder item: #'smallchat mcp console')
        parent: #Tools;
        order: 103;
        help: 'Inspect live MCP connections and their tool calls';
        icon: (self iconNamed: #smallSystemConfiguration);
        action: [ UIManager default defer: [ self open ] ]
]

{ #category : 'opening' }
SmallChatMCPConsoleWindow class >> open [
    "Open a console window bound to the live default TCP server. Used
     by the world-menu launcher and by callers that want a tabbed view
     of MCP traffic."
    ^ self new
        bindServer: SmallChatMCPTcpServer default;
        open;
        yourself
]

{ #category : 'private' }
SmallChatMCPConsoleWindow >> addTabFor: aConnection [
    "Eagerly instantiate a panel + page for the connection so tool calls
     are recorded into a live subscriber from the moment the connection
     opens, regardless of whether the tab is currently selected."
    | panel page |
    (panelsByConnection includesKey: aConnection) ifTrue: [ ^ self ].
    panel := SmallChatMCPConnectionPanel new.
    panel uiDeferrer: uiDeferrer.
    panel bindConnection: aConnection announcer: announcer.
    page := SpNotebookPage
        title: (self titleForConnection: aConnection)
        provider: [ panel ].
    notebook addPage: page.
    panelsByConnection at: aConnection put: { panel. page }
]

{ #category : 'binding' }
SmallChatMCPConsoleWindow >> bindServer: aServer [
    "Snapshot the server's currently-active connections and build one
     tab per connection, then subscribe so subsequent connect/disconnect
     events keep the notebook in sync. Each tab pre-builds its panel
     and pre-binds it to the announcer so tool calls accumulate even
     while the tab isn't selected."
    server := aServer.
    announcer := aServer announcer.
    aServer connections do: [ :conn | self addTabFor: conn ].
    self subscribeToAnnouncer
]

{ #category : 'lifecycle' }
SmallChatMCPConsoleWindow >> cleanup [
    "Drop the window's announcer subscription, then cascade cleanup to
     each tab's panel so their per-connection subscriptions also go.
     Idempotent."
    announcer ifNotNil: [
        announcer unsubscribe: self.
        announcer := nil ].
    panelsByConnection valuesDo: [ :entry | entry first cleanup ]
]

{ #category : 'private' }
SmallChatMCPConsoleWindow >> closeTabFor: aConnection [
    "On disconnect, the connection has already been markClosed by the
     TCP server. Update the page title in place so the user sees the
     '(closed)' marker; the panel and its records remain inspectable
     until the console window itself is closed."
    | entry page |
    entry := panelsByConnection at: aConnection ifAbsent: [ ^ self ].
    page := entry second.
    page title: (self titleForConnection: aConnection)
]

{ #category : 'layout' }
SmallChatMCPConsoleWindow >> defaultLayout [
    ^ SpBoxLayout newTopToBottom add: notebook; yourself
]

{ #category : 'initialization' }
SmallChatMCPConsoleWindow >> initializePresenters [
    uiDeferrer := [ :aBlock | UIManager default defer: aBlock ].
    panelsByConnection := IdentityDictionary new.
    notebook := self newNotebook
]

{ #category : 'initialization' }
SmallChatMCPConsoleWindow >> initializeWindow: aWindow [
    aWindow
        title: 'smallchat MCP console';
        initialExtent: 720 @ 480;
        whenClosedDo: [ self cleanup ]
]

{ #category : 'accessing' }
SmallChatMCPConsoleWindow >> pageEntryFor: aConnection [
    "Test-facing accessor: the {panel. page} pair for aConnection, or
     nil if no tab is mounted."
    ^ panelsByConnection at: aConnection ifAbsent: [ nil ]
]

{ #category : 'accessing' }
SmallChatMCPConsoleWindow >> pages [
    "Currently-mounted notebook pages, one per connection (live or
     closed-but-still-displayed)."
    ^ notebook pages
]

{ #category : 'private' }
SmallChatMCPConsoleWindow >> subscribeToAnnouncer [
    announcer
        when: SmallChatMCPConnectionAdded
        do: [ :ann | uiDeferrer value: [ self addTabFor: ann connection ] ]
        for: self.
    announcer
        when: SmallChatMCPConnectionRemoved
        do: [ :ann | uiDeferrer value: [ self closeTabFor: ann connection ] ]
        for: self
]

{ #category : 'private' }
SmallChatMCPConsoleWindow >> titleForConnection: aConnection [
    | base |
    base := 'conn #' , aConnection id asString.
    aConnection isClosed ifTrue: [ ^ base , ' (closed)' ].
    ^ base
]

{ #category : 'accessing' }
SmallChatMCPConsoleWindow >> uiDeferrer: aBlock [ uiDeferrer := aBlock
]
