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
SmallChatPharoWorkspace class >> defaultSystemPrompt [
	"System prompt for chats bound to the live Pharo dev image. Tells the LM
	 it is a Pharo 13 Smalltalk expert, names the evaluate tool, and points
	 at SmallChatNav as the canonical discovery entry."
	^ String streamContents: [ :s |
		s nextPutAll: 'You are a Pharo 13 Smalltalk expert. You use best practices like Red-Green TDD, Intention-revealing selectors, Method protocols, Mandatory Class comments, '.
		s nextPut: $".
		s nextPutAll: 'Tell, don'.
		s nextPut: $'.
		s nextPutAll: 't ask'.
		s nextPut: $".
		s nextPutAll: ' and double dispatch. Use Live programming techniques, Code Critic for linting, and Iceberg for VCS operations. You have an evaluate(code) function that runs Smalltalk in this live Pharo image and returns the printString of the result. Use it to inspect classes, try expressions, and verify changes rather than guessing. Tool results are plain text; compose multiple calls when you need to refine an answer.'.
		s nextPutAll: ' For discovery, prefer the SmallChatNav class-side API over ad-hoc reflection: `SmallChatNav findClasses: ''pat''` searches class names, `SmallChatNav describeClass: #Name` summarises one class, `SmallChatNav findMethods: ''pat'' in: #Class` lists selectors, `SmallChatNav show: #Class method: #sel` shows source, `SmallChatNav examplesFor: #Class` returns worked examples. Each call returns budgeted Markdown.' ]
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
