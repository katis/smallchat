Class {
	#name : 'SmallChatMCPAnnouncementsTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatMCPAnnouncementsTest >> testConnectionAddedCarriesConnection [
    | conn ann |
    conn := SmallChatMCPConnection on: Object new.
    ann := SmallChatMCPConnectionAdded new connection: conn; yourself.
    self assert: ann connection == conn
]

{ #category : 'tests' }
SmallChatMCPAnnouncementsTest >> testConnectionRemovedCarriesConnection [
    | conn ann |
    conn := SmallChatMCPConnection on: Object new.
    conn markClosed.
    ann := SmallChatMCPConnectionRemoved new connection: conn; yourself.
    self assert: ann connection == conn.
    self assert: ann connection isClosed
]

{ #category : 'tests' }
SmallChatMCPAnnouncementsTest >> testToolCallRecordedCarriesConnectionAndRecord [
    | conn record ann |
    conn := SmallChatMCPConnection on: Object new.
    record := SmallChatMCPCallRecord new.
    ann := SmallChatMCPToolCallRecorded new
        connection: conn;
        record: record;
        yourself.
    self assert: ann connection == conn.
    self assert: ann record == record
]
