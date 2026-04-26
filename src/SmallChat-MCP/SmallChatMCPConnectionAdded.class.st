"
Fired when the TCP server registers a fresh SmallChatMCPConnection
on accept. Carries the connection so subscribers can build a tab,
register listeners, etc., without polling.
"
Class {
	#name : 'SmallChatMCPConnectionAdded',
	#superclass : 'Announcement',
	#instVars : [
		'connection'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing' }
SmallChatMCPConnectionAdded >> connection [ ^ connection
]

{ #category : 'accessing' }
SmallChatMCPConnectionAdded >> connection: aConnection [ connection := aConnection
]
