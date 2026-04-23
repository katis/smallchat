Class {
	#name : 'SmallChatMCPStateChanged',
	#superclass : 'Announcement',
	#instVars : [
		'running',
		'clientCount'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing' }
SmallChatMCPStateChanged >> clientCount [ ^ clientCount
]

{ #category : 'accessing' }
SmallChatMCPStateChanged >> clientCount: anInteger [ clientCount := anInteger
]

{ #category : 'accessing' }
SmallChatMCPStateChanged >> running [ ^ running
]

{ #category : 'accessing' }
SmallChatMCPStateChanged >> running: aBoolean [ running := aBoolean
]
