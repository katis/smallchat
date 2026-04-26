Class {
	#name : 'SmallChatLMSessionStatusChanged',
	#superclass : 'Announcement',
	#instVars : [
		'session',
		'status'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatLMSessionStatusChanged >> session [ ^ session
]

{ #category : 'accessing' }
SmallChatLMSessionStatusChanged >> session: aSession [ session := aSession
]

{ #category : 'accessing' }
SmallChatLMSessionStatusChanged >> status [ ^ status
]

{ #category : 'accessing' }
SmallChatLMSessionStatusChanged >> status: aSymbol [ status := aSymbol
]
