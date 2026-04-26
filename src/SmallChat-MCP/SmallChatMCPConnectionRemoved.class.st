"
Fired when the TCP server unregisters a SmallChatMCPConnection on
session teardown (normal EOF or error). The connection has already
been markClosed, so isClosed is true on receipt.
"
Class {
	#name : 'SmallChatMCPConnectionRemoved',
	#superclass : 'Announcement',
	#instVars : [
		'connection'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing' }
SmallChatMCPConnectionRemoved >> connection [ ^ connection
]

{ #category : 'accessing' }
SmallChatMCPConnectionRemoved >> connection: aConnection [ connection := aConnection
]
