"
Per-TCP-connection bookkeeping for the MCP server. Wraps the live
socket plus a monotonic id, openedAt/closedAt timestamps, and an
ordered log of recorded SmallChatMCPCallRecord entries (one per
``tools/call`` request that crossed this connection).

The TCP server creates one of these on accept, hands it to the
client-handling fork, and marks it closed on session teardown. The
MCP console window subscribes to SmallChatMCPConnectionAdded /
SmallChatMCPConnectionRemoved / SmallChatMCPToolCallRecorded to
keep its tabs in sync.
"
Class {
	#name : 'SmallChatMCPConnection',
	#superclass : 'Object',
	#instVars : [
		'id',
		'socket',
		'openedAt',
		'closedAt',
		'calls'
	],
	#classInstVars : [
		'nextId'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'instance creation' }
SmallChatMCPConnection class >> nextId [
    "Monotonic per-image identifier. Class-instance state -- survives
     recompiles, resets on image start with the rest of class-side state."
    nextId := (nextId ifNil: [ 0 ]) + 1.
    ^ nextId
]

{ #category : 'instance creation' }
SmallChatMCPConnection class >> on: aSocket [
    "Build a fresh connection wrapper around aSocket with a unique id and
     openedAt stamped to now."
    ^ self new initializeId: self nextId on: aSocket
]

{ #category : 'accessing' }
SmallChatMCPConnection >> calls [
    "Live OrderedCollection -- the TCP server appends records under the
     mutex; readers see them in arrival order."
    ^ calls
]

{ #category : 'accessing' }
SmallChatMCPConnection >> closedAt [ ^ closedAt
]

{ #category : 'accessing' }
SmallChatMCPConnection >> id [ ^ id
]

{ #category : 'private' }
SmallChatMCPConnection >> initializeId: anInteger on: aSocket [
    id := anInteger.
    socket := aSocket.
    openedAt := DateAndTime now.
    closedAt := nil.
    calls := OrderedCollection new
]

{ #category : 'testing' }
SmallChatMCPConnection >> isClosed [ ^ closedAt notNil
]

{ #category : 'lifecycle' }
SmallChatMCPConnection >> markClosed [
    "Stamp closedAt with the current instant. Idempotent: a second call
     overwrites the timestamp but leaves isClosed true."
    closedAt := DateAndTime now
]

{ #category : 'accessing' }
SmallChatMCPConnection >> openedAt [ ^ openedAt
]

{ #category : 'accessing' }
SmallChatMCPConnection >> socket [ ^ socket
]
