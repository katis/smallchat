Class {
	#name : 'SmallChatTsWorkspace',
	#superclass : 'SmallChatWorkspace',
	#instVars : [
		'path',
		'lspClient',
		'attachedAt'
	],
	#classVars : [
		'LauncherBlock'
	],
	#category : 'SmallChat-Workspace',
	#package : 'SmallChat-Workspace'
}

{ #category : 'instance creation' }
SmallChatTsWorkspace class >> attachAt: aPath name: aNameOrNil [
	"Build a TS workspace rooted at aPath. Canonicalises and refuses
	 relative paths. aNameOrNil defaults to the canonical path basename."
	| ref ws nm client |
	ref := self canonicalise: aPath.
	nm := aNameOrNil ifNil: [ ref basename ].
	client := self launcherBlock value: ref.
	ws := self new
		name: nm;
		path: ref;
		lspClient: client;
		attachedAt: DateAndTime now;
		yourself.
	^ ws
]

{ #category : 'private' }
SmallChatTsWorkspace class >> canonicalise: aString [
	"Return an absolute, resolved FileReference. Raise on relative input."
	| ref |
	(aString isString and: [ aString isEmpty not ])
		ifFalse: [ self error: 'path must be a non-empty string' ].
	ref := aString asFileReference.
	ref isAbsolute ifFalse: [
		self error: 'path must be absolute (was: ' , aString , '). The agent''s cwd is unreliable.' ].
	^ ref resolve
]

{ #category : 'accessing' }
SmallChatTsWorkspace class >> default [
	"No default TS workspace -- they are opt-in via workspace.attach-ts."
	^ nil
]

{ #category : 'accessing' }
SmallChatTsWorkspace class >> kind [ ^ #ts
]

{ #category : 'accessing' }
SmallChatTsWorkspace class >> launcherBlock [
	"Block (path -> SmallChatLSPClient) used to launch tsgo on attach.
	 Tests swap this for a stub that returns a stub-transport client.
	 Default returns nil (real tsgo wiring lands in step 11)."
	^ LauncherBlock ifNil: [ [ :path | nil ] ]
]

{ #category : 'accessing' }
SmallChatTsWorkspace class >> launcherBlock: aBlock [
	LauncherBlock := aBlock
]

{ #category : 'accessing' }
SmallChatTsWorkspace class >> resetLauncherBlock [
	LauncherBlock := nil
]

{ #category : 'accessing' }
SmallChatTsWorkspace >> attachedAt [ ^ attachedAt
]

{ #category : 'accessing' }
SmallChatTsWorkspace >> attachedAt: aDateAndTime [ attachedAt := aDateAndTime
]

{ #category : 'accessing' }
SmallChatTsWorkspace >> describeAsDict [
	| dict |
	dict := super describeAsDict.
	path ifNotNil: [ dict at: 'path' put: path fullName ].
	attachedAt ifNotNil: [ dict at: 'attachedAt' put: attachedAt printString ].
	^ dict
]

{ #category : 'accessing' }
SmallChatTsWorkspace >> lspClient [ ^ lspClient
]

{ #category : 'accessing' }
SmallChatTsWorkspace >> lspClient: aClient [ lspClient := aClient
]

{ #category : 'accessing' }
SmallChatTsWorkspace >> path [ ^ path
]

{ #category : 'accessing' }
SmallChatTsWorkspace >> path: aRef [ path := aRef
]

{ #category : 'lifecycle' }
SmallChatTsWorkspace >> shutdown [
	"Stop the LSP client and drop it. Idempotent: safe after the first call."
	lspClient ifNotNil: [
		[ lspClient shutdown ] on: Error do: [ :_ | nil ].
		lspClient := nil ].
	^ self
]
