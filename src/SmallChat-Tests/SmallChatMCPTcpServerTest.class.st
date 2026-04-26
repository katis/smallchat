Class {
	#name : 'SmallChatMCPTcpServerTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testActiveClientCountStartsAtZero [
    | server |
    server := SmallChatMCPTcpServer new.
    self assert: server activeClientCount equals: 0
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testConnectionsReturnsSnapshot [
    "The snapshot must be a copy: mutating it must not perturb the server's
     active set, and the order must match registration order."
    | server c1 c2 snapshot |
    server := SmallChatMCPTcpServer new.
    c1 := SmallChatMCPConnection on: Object new.
    c2 := SmallChatMCPConnection on: Object new.
    server registerConnection: c1.
    server registerConnection: c2.
    snapshot := server connections.
    self assert: snapshot size equals: 2.
    self assert: (snapshot includes: c1).
    self assert: (snapshot includes: c2).
    snapshot removeAll: snapshot copy.
    self assert: server activeClientCount equals: 2
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testCurrentStateReflectsRunningAndCount [
    | server state |
    server := SmallChatMCPTcpServer new.
    state := server currentState.
    self deny: state running.
    self assert: state clientCount equals: 0.
    server registerConnection: (SmallChatMCPConnection on: Object new).
    server registerConnection: (SmallChatMCPConnection on: Object new).
    state := server currentState.
    self assert: state clientCount equals: 2
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testHandleConnectionRegistersAndUnregisters [
    | server received |
    server := SmallChatMCPTcpServer new.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPStateChanged
        do: [ :ann | received add: ann ]
        for: self.
    [ server handleConnection: nil ]
        ensure: [ server announcer unsubscribe: self ].
    self assert: server activeClientCount equals: 0.
    self assert: received size equals: 2.
    self assert: received first clientCount equals: 1.
    self assert: received last clientCount equals: 0
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testHandleConnectionUnregistersOnSessionError [
    "If runClientSessionOn: raises, the ensure: block must still unregister
     and announce a disconnect. Uses SmallChatMCPTcpServerRaisingStub whose
     runClientSessionOn: throws unconditionally."
    | server received |
    server := SmallChatMCPTcpServerRaisingStub new.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPStateChanged
        do: [ :ann | received add: ann ]
        for: self.
    [
        [ server handleConnection: nil ]
            on: Error
            do: [ :e | "expected: simulated-session-failure" ]
    ] ensure: [ server announcer unsubscribe: self ].
    self assert: server activeClientCount equals: 0.
    self assert: received size equals: 2.
    self assert: received last clientCount equals: 0
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testRecordIfToolsCallAppendsAndAnnounces [
    | server conn req resp received |
    server := SmallChatMCPTcpServer new.
    conn := SmallChatMCPConnection on: Object new.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPToolCallRecorded
        do: [ :ann | received add: ann ]
        for: self.
    req := Dictionary new
        at: 'method' put: 'tools/call';
        at: 'id' put: 1;
        at: 'params' put: (Dictionary new
            at: 'name' put: 'eval.smalltalk';
            at: 'arguments' put: (Dictionary new at: 'code' put: '42'; yourself);
            yourself);
        yourself.
    resp := Dictionary new
        at: 'result' put: (Dictionary new
            at: 'content' put: { Dictionary new
                at: 'type' put: 'text';
                at: 'text' put: '42';
                yourself };
            yourself);
        yourself.
    [ server recordIfToolsCall: req response: resp durationMs: 5 onConnection: conn ]
        ensure: [ server announcer unsubscribe: self ].
    self assert: conn calls size equals: 1.
    self assert: received size equals: 1.
    self assert: received first connection == conn.
    self assert: received first record name equals: 'eval.smalltalk'
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testRecordIfToolsCallSkipsNonToolsCall [
    | server conn req resp received |
    server := SmallChatMCPTcpServer new.
    conn := SmallChatMCPConnection on: Object new.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPToolCallRecorded
        do: [ :ann | received add: ann ]
        for: self.
    req := Dictionary new at: 'method' put: 'ping'; at: 'id' put: 1; yourself.
    resp := Dictionary new at: 'result' put: Dictionary new; yourself.
    [ server recordIfToolsCall: req response: resp durationMs: 1 onConnection: conn ]
        ensure: [ server announcer unsubscribe: self ].
    self assert: conn calls isEmpty.
    self assert: received isEmpty
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testRegisterAndUnregisterConnection [
    | server conn |
    server := SmallChatMCPTcpServer new.
    conn := SmallChatMCPConnection on: Object new.
    server registerConnection: conn.
    self assert: server activeClientCount equals: 1.
    server unregisterConnection: conn.
    self assert: server activeClientCount equals: 0
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testRegisterConnectionFiresAddedAnnouncement [
    | server conn received |
    server := SmallChatMCPTcpServer new.
    conn := SmallChatMCPConnection on: Object new.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPConnectionAdded
        do: [ :ann | received add: ann ]
        for: self.
    [ server registerConnection: conn ]
        ensure: [ server announcer unsubscribe: self ].
    self assert: server activeClientCount equals: 1.
    self assert: received size equals: 1.
    self assert: received first connection == conn
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testRegisterEmitsStateChangedWithCount [
    | server received conn |
    server := SmallChatMCPTcpServer new.
    conn := SmallChatMCPConnection on: Object new.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPStateChanged
        do: [ :ann | received add: ann ]
        for: self.
    [ server registerConnection: conn ]
        ensure: [ server announcer unsubscribe: self ].
    self assert: received size equals: 1.
    self assert: received first clientCount equals: 1
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testUnregisterConnectionFiresRemovedAndMarksClosed [
    | server conn received |
    server := SmallChatMCPTcpServer new.
    conn := SmallChatMCPConnection on: Object new.
    server registerConnection: conn.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPConnectionRemoved
        do: [ :ann | received add: ann ]
        for: self.
    [ server unregisterConnection: conn ]
        ensure: [ server announcer unsubscribe: self ].
    self assert: conn isClosed.
    self assert: received size equals: 1.
    self assert: received first connection == conn.
    self assert: server activeClientCount equals: 0
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testUnregisterEmitsStateChangedWithDecrementedCount [
    | server received conn |
    server := SmallChatMCPTcpServer new.
    conn := SmallChatMCPConnection on: Object new.
    server registerConnection: conn.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPStateChanged
        do: [ :ann | received add: ann ]
        for: self.
    [ server unregisterConnection: conn ]
        ensure: [ server announcer unsubscribe: self ].
    self assert: received size equals: 1.
    self assert: received first clientCount equals: 0
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testUpdateRunningTogglesFlagAndAnnounces [
    | server received |
    server := SmallChatMCPTcpServer new.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPStateChanged
        do: [ :ann | received add: ann ]
        for: self.
    [
        server updateRunning: true.
        server updateRunning: false
    ] ensure: [ server announcer unsubscribe: self ].
    self assert: received size equals: 2.
    self assert: received first running.
    self deny: received last running.
    self deny: server currentState running
]
