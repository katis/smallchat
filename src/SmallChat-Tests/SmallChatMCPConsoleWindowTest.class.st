Class {
	#name : 'SmallChatMCPConsoleWindowTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatMCPConsoleWindowTest >> testCleanupUnsubscribes [
    | server window |
    server := SmallChatMCPTcpServer new.
    window := self windowOn: server.
    window cleanup.
    server registerConnection: (SmallChatMCPConnection on: Object new).
    self assert: window pages isEmpty
]

{ #category : 'tests' }
SmallChatMCPConsoleWindowTest >> testInitiallyMirrorsServersConnections [
    | server c1 c2 window |
    server := SmallChatMCPTcpServer new.
    c1 := SmallChatMCPConnection on: Object new.
    c2 := SmallChatMCPConnection on: Object new.
    server registerConnection: c1.
    server registerConnection: c2.
    window := self windowOn: server.
    self assert: window pages size equals: 2
]

{ #category : 'tests' }
SmallChatMCPConsoleWindowTest >> testNewConnectionAddsTab [
    | server window c1 |
    server := SmallChatMCPTcpServer new.
    window := self windowOn: server.
    c1 := SmallChatMCPConnection on: Object new.
    server registerConnection: c1.
    self assert: window pages size equals: 1.
    self assert: (window titleForConnection: c1) equals: 'conn #' , c1 id asString
]

{ #category : 'tests' }
SmallChatMCPConsoleWindowTest >> testRemovedConnectionMarksTabClosedAndKeeps [
    | server window c1 entry |
    server := SmallChatMCPTcpServer new.
    c1 := SmallChatMCPConnection on: Object new.
    server registerConnection: c1.
    window := self windowOn: server.
    server unregisterConnection: c1.
    self assert: window pages size equals: 1.
    self assert: ((window titleForConnection: c1) endsWith: '(closed)').
    entry := window pageEntryFor: c1.
    self assert: entry second title equals: (window titleForConnection: c1)
]

{ #category : 'tests' }
SmallChatMCPConsoleWindowTest >> testWorldMenuPragmaPresent [
    "Class-side <worldMenu> launcher exists."
    | method |
    method := SmallChatMCPConsoleWindow class >> #consoleMenuCommandOn:.
    self assert: (method pragmas anySatisfy: [ :p | p selector = #worldMenu ])
]

{ #category : 'helpers' }
SmallChatMCPConsoleWindowTest >> windowOn: aServer [
    ^ SmallChatMCPConsoleWindow new
        uiDeferrer: [ :blk | blk value ];
        bindServer: aServer;
        yourself
]
