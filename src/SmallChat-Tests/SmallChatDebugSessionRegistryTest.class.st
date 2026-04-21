Class {
	#name : 'SmallChatDebugSessionRegistryTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatDebugSessionRegistryTest >> testAddAndFetch [
    | registry session |
    registry := SmallChatDebugSessionRegistry new.
    session := SmallChatDebugSession new id: 'ds-1'.
    registry add: session.
    self assert: (registry at: 'ds-1') == session
]

{ #category : 'tests' }
SmallChatDebugSessionRegistryTest >> testCapEvictsOldest [
    | registry sessions |
    registry := SmallChatDebugSessionRegistry new.
    registry maxOpen: 2.
    sessions := (1 to: 3) collect: [ :i |
        | p s |
        p := [ Processor activeProcess suspend ] forkNamed: 'registry-cap-test-' , i asString.
        (Delay forMilliseconds: 1) wait.
        s := SmallChatDebugSession new
            id: 'ds-' , i asString;
            process: p.
        registry add: s.
        s ].
    self assert: registry size equals: 2.
    self should: [ registry at: 'ds-1' ] raise: Error.
    self assert: sessions first process isTerminated.
    self assert: (registry at: 'ds-2') id equals: 'ds-2'.
    self assert: (registry at: 'ds-3') id equals: 'ds-3'
]

{ #category : 'tests' }
SmallChatDebugSessionRegistryTest >> testTtlEviction [
    | registry nowMs |
    nowMs := 1000.
    registry := SmallChatDebugSessionRegistry new.
    registry clock: [ nowMs ].
    registry ttlMilliseconds: 5000.
    registry add: (SmallChatDebugSession new id: 'old').
    nowMs := nowMs + 6000.
    self should: [ registry at: 'old' ] raise: Error.
    self assert: registry size equals: 0
]
