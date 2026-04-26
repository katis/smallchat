Class {
	#name : 'SmallChatTsWorkspace',
	#superclass : 'SmallChatWorkspace',
	#instVars : [
		'path',
		'lspClient',
		'attachedAt',
		'famixModel',
		'famixImporter'
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
SmallChatTsWorkspace class >> defaultSystemPrompt [
	"System prompt for chats bound to a TypeScript workspace. Placeholder --
	 final body lands in slice 5 alongside the SmallChatTsNav helper. For
	 now: mention the workspace kind and the canonical nav entry the agent
	 should reach for."
	^ 'You are working inside a TypeScript workspace. Drive reads, edits, and refactors through the evaluate(code) tool calling SmallChatTsNav.'
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

{ #category : 'famix' }
SmallChatTsWorkspace >> famixImporter [
	"Lazy SmallChatFamixImporter wired against this workspace's LSP client +
	 a fresh tree-sitter parser/walker. Tests that supply only CSS files can
	 use a workspace with a nil lspClient -- the CSS path does not require
	 LSP. Cleared by #shutdown."
	^ famixImporter ifNil: [
		famixImporter := SmallChatFamixImporter new
			model: SmallChatFamixModel new
			client: lspClient
			parser: SmallChatTSParser new
			walker: SmallChatTSNodeWalker new ]
]

{ #category : 'famix' }
SmallChatTsWorkspace >> famixModel [
	"Lazy whole-project Famix model. First call walks the workspace path via
	 SmallChatFamixImporter importAllUnder:; subsequent calls reuse the same
	 model. SmallChatTsNav reads from this for findFiles:, findSymbol: and
	 friends. Cleared by #shutdown. May take seconds on first call for a
	 large project."
	^ famixModel ifNil: [
		self famixImporter importAllUnder: path.
		famixModel := self famixImporter model ]
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
	"Stop the LSP client and drop it; clear the cached Famix model +
	 importer so re-attaching the same path rebuilds rather than handing
	 back stale entities. Idempotent: safe after the first call."
	lspClient ifNotNil: [
		[ lspClient shutdown ] on: Error do: [ :_ | nil ].
		lspClient := nil ].
	famixModel := nil.
	famixImporter := nil.
	^ self
]
