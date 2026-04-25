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

{ #category : 'accessing' }
SmallChatPharoWorkspace >> describeAsDict [
	| dict repo |
	dict := super describeAsDict.
	dict at: 'imagePath' put: ([ Smalltalk vm imageFile fullName ] on: Error do: [ :_ | '<unknown>' ]).
	(Smalltalk globals at: #IceRepository ifAbsent: [ nil ]) ifNotNil: [
		repo := IceRepository registry detect: [ :r | ([ r name ] on: Error do: [ :_ | nil ]) = 'smallchat' ] ifNone: [ nil ].
		repo ifNotNil: [ dict at: 'branch' put: ([ repo branchName ] on: Error do: [ :_ | '<unknown>' ]) ] ].
	^ dict
]
