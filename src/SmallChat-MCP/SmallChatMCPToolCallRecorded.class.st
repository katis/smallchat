"
Fired after the TCP server records one tools/call dispatch onto a
SmallChatMCPConnection. Subscribers filter by connection identity to
update one tab; the record is the freshly-appended entry.
"
Class {
	#name : 'SmallChatMCPToolCallRecorded',
	#superclass : 'Announcement',
	#instVars : [
		'connection',
		'record'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing' }
SmallChatMCPToolCallRecorded >> connection [ ^ connection
]

{ #category : 'accessing' }
SmallChatMCPToolCallRecorded >> connection: aConnection [ connection := aConnection
]

{ #category : 'accessing' }
SmallChatMCPToolCallRecorded >> record [ ^ record
]

{ #category : 'accessing' }
SmallChatMCPToolCallRecorded >> record: aRecord [ record := aRecord
]
