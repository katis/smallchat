Class {
	#name : 'SmallChatMCPConnectionPanelTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'helpers' }
SmallChatMCPConnectionPanelTest >> panelOn: aConnection announcer: anAnnouncer [
    ^ SmallChatMCPConnectionPanel new
        uiDeferrer: [ :blk | blk value ];
        bindConnection: aConnection announcer: anAnnouncer;
        yourself
]

{ #category : 'helpers' }
SmallChatMCPConnectionPanelTest >> recordNamed: aName output: aResult [
    ^ self recordNamed: aName output: aResult isError: false
]

{ #category : 'helpers' }
SmallChatMCPConnectionPanelTest >> recordNamed: aName output: aResult isError: aBool [
    | req resp |
    req := Dictionary new
        at: 'method' put: 'tools/call';
        at: 'id' put: 1;
        at: 'params' put: (Dictionary new
            at: 'name' put: aName;
            at: 'arguments' put: (Dictionary new at: 'arg' put: aName; yourself);
            yourself);
        yourself.
    aBool
        ifFalse: [
            resp := Dictionary new
                at: 'result' put: (Dictionary new
                    at: 'content' put: { Dictionary new
                        at: 'type' put: 'text';
                        at: 'text' put: aResult;
                        yourself };
                    yourself);
                yourself ]
        ifTrue: [
            resp := Dictionary new
                at: 'result' put: (Dictionary new
                    at: 'content' put: { Dictionary new
                        at: 'type' put: 'text';
                        at: 'text' put: aResult;
                        yourself };
                    at: 'isError' put: true;
                    yourself);
                yourself ].
    ^ SmallChatMCPCallRecord from: req response: resp durationMs: 1
]

{ #category : 'tests' }
SmallChatMCPConnectionPanelTest >> testCleanupUnsubscribesFromAnnouncer [
    | conn r announcer panel |
    conn := SmallChatMCPConnection on: Object new.
    announcer := Announcer new.
    panel := self panelOn: conn announcer: announcer.
    panel cleanup.
    r := self recordNamed: 'late' output: 'should-not-render'.
    conn calls add: r.
    announcer announce: (SmallChatMCPToolCallRecorded new
        connection: conn;
        record: r;
        yourself).
    self assert: panel records isEmpty
]

{ #category : 'tests' }
SmallChatMCPConnectionPanelTest >> testErrorRecordPrefixesOutput [
    | conn r panel |
    conn := SmallChatMCPConnection on: Object new.
    r := self recordNamed: 'broken' output: 'boom' isError: true.
    conn calls add: r.
    panel := self panelOn: conn announcer: Announcer new.
    panel selectRecord: r.
    self assert: (panel outputText text beginsWith: '[error]').
    self assert: (panel outputText text includesSubstring: 'boom')
]

{ #category : 'tests' }
SmallChatMCPConnectionPanelTest >> testIgnoresAnnouncementsForOtherConnection [
    | conn other r1 stranger announcer panel |
    conn := SmallChatMCPConnection on: Object new.
    other := SmallChatMCPConnection on: Object new.
    r1 := self recordNamed: 'eval.smalltalk' output: '42'.
    conn calls add: r1.
    announcer := Announcer new.
    panel := self panelOn: conn announcer: announcer.
    stranger := self recordNamed: 'vcs.status' output: '(clean)'.
    other calls add: stranger.
    announcer announce: (SmallChatMCPToolCallRecorded new
        connection: other;
        record: stranger;
        yourself).
    self assert: panel records size equals: 1
]

{ #category : 'tests' }
SmallChatMCPConnectionPanelTest >> testListsExistingCalls [
    | conn r1 r2 panel |
    conn := SmallChatMCPConnection on: Object new.
    r1 := self recordNamed: 'eval.smalltalk' output: '42'.
    r2 := self recordNamed: 'vcs.status' output: '(clean)'.
    conn calls add: r1; add: r2.
    panel := self panelOn: conn announcer: Announcer new.
    self assert: panel records asArray equals: { r1. r2 }
]

{ #category : 'tests' }
SmallChatMCPConnectionPanelTest >> testRefreshesOnRecordedAnnouncementForOurConnection [
    | conn r1 r2 announcer panel |
    conn := SmallChatMCPConnection on: Object new.
    r1 := self recordNamed: 'eval.smalltalk' output: '42'.
    conn calls add: r1.
    announcer := Announcer new.
    panel := self panelOn: conn announcer: announcer.
    self assert: panel records size equals: 1.
    r2 := self recordNamed: 'eval.smalltalk' output: '99'.
    conn calls add: r2.
    announcer announce: (SmallChatMCPToolCallRecorded new
        connection: conn;
        record: r2;
        yourself).
    self assert: panel records size equals: 2.
    self assert: (panel records asArray includes: r2)
]

{ #category : 'tests' }
SmallChatMCPConnectionPanelTest >> testSelectionUpdatesInputAndOutput [
    | conn r1 panel |
    conn := SmallChatMCPConnection on: Object new.
    r1 := self recordNamed: 'eval.smalltalk' output: '42'.
    conn calls add: r1.
    panel := self panelOn: conn announcer: Announcer new.
    panel selectRecord: r1.
    self assert: panel inputText text equals: r1 argumentsJson.
    self assert: panel outputText text equals: '42'
]
