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
SmallChatMCPTcpServerTest >> testCurrentStateReflectsRunningAndCount [
    | server state |
    server := SmallChatMCPTcpServer new.
    state := server currentState.
    self deny: state running.
    self assert: state clientCount equals: 0.
    server registerClient: #a.
    server registerClient: #b.
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
SmallChatMCPTcpServerTest >> testRegisterAndUnregisterClient [
    | server marker |
    server := SmallChatMCPTcpServer new.
    marker := Object new.
    server registerClient: marker.
    self assert: server activeClientCount equals: 1.
    server unregisterClient: marker.
    self assert: server activeClientCount equals: 0
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testRegisterEmitsStateChangedWithCount [
    | server received |
    server := SmallChatMCPTcpServer new.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPStateChanged
        do: [ :ann | received add: ann ]
        for: self.
    [ server registerClient: #c1 ]
        ensure: [ server announcer unsubscribe: self ].
    self assert: received size equals: 1.
    self assert: received first clientCount equals: 1
]

{ #category : 'tests' }
SmallChatMCPTcpServerTest >> testUnregisterEmitsStateChangedWithDecrementedCount [
    | server received |
    server := SmallChatMCPTcpServer new.
    server registerClient: #c1.
    received := OrderedCollection new.
    server announcer
        when: SmallChatMCPStateChanged
        do: [ :ann | received add: ann ]
        for: self.
    [ server unregisterClient: #c1 ]
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
