Class {
	#name : 'SmallChatPharoWorkspace',
	#superclass : 'SmallChatWorkspace',
	#classVars : [
		'Default'
	],
	#category : 'SmallChat-Workspace',
	#package : 'SmallChat-Workspace'
}

{ #category : 'accessing' }
SmallChatPharoWorkspace class >> default [
	"Singleton instance representing the live Pharo dev image."
	^ Default ifNil: [ Default := self new name: 'pharo'; yourself ]
]

{ #category : 'accessing' }
SmallChatPharoWorkspace class >> kind [ ^ #pharo
]

{ #category : 'accessing' }
SmallChatPharoWorkspace class >> reset [
	"Test seam: drop the cached singleton."
	Default := nil
]
