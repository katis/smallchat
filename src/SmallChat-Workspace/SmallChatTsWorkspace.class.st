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
	"System prompt for chats bound to a TypeScript workspace. Names the
	 LSP server (tsgo) + Famix model, forbids dead-end Pharo APIs, and
	 hands the agent two pivot classes -- SmallChatTsNav for the project,
	 SmallChatNav for live discovery -- instead of enumerating every
	 selector. Kept ASCII-only because Tonel + Pharo do not round-trip BMP
	 unicode reliably."
	^ String streamContents: [ :s |
		s nextPutAll: 'You are working inside a TypeScript workspace served by a tsgo Language Server, with an in-image Famix model that indexes the project. Drive every read, edit, and refactor through the evaluate(code) tool.'; lf; lf.
		s nextPutAll: 'Two classes anchor the workflow:'; lf.
		s nextPutAll: '* SmallChatTsNav -- the project API. Find files / symbols / references, read and write source, rename and apply LSP code actions. All selectors are class-side, so call as `SmallChatTsNav findSymbol: ''Foo''`.'; lf.
		s nextPutAll: '* SmallChatNav -- the discovery tool for the live Pharo image. Use it to learn SmallChatTsNav''s surface and the exact selector / argument shape, instead of guessing:'; lf.
		s nextPutAll: '  * `SmallChatNav describeClass: #SmallChatTsNav` -- public selectors grouped by protocol.'; lf.
		s nextPutAll: '  * `SmallChatNav findMethods: ''pat'' in: #SmallChatTsNav` -- locate a selector by partial name.'; lf.
		s nextPutAll: '  * `SmallChatNav show: #SmallChatTsNav method: #aSelector` -- comment, signature, source.'; lf.
		s nextPutAll: '  * `SmallChatNav findClasses: ''pat''` -- locate other in-image classes when you need them.'; lf.
		s nextPutAll: 'The same selectors work for any class -- explore SmallChatLSPClient, SmallChatFamixModel, etc. when needed.'; lf; lf.
		s nextPutAll: 'Hard rule: no FileDirectory, FileSystem disk, OSSubprocess, or shell commands -- they are dead ends in this context. SmallChatTsNav handles file IO, the LSP client handles diagnostics, the Famix model handles symbol queries.'; lf; lf.
		s nextPutAll: 'The first call to a SmallChatTsNav discovery selector walks the project to populate the Famix model and may take several seconds. Subsequent calls are in-memory.'; lf; lf.
		s nextPutAll: 'Worked example -- rename a symbol in two discovery hops:'; lf.
		s nextPutAll: '1. `SmallChatNav findMethods: ''rename'' in: #SmallChatTsNav` -> finds renameSymbolAt:line:character:to:.'; lf.
		s nextPutAll: '2. `SmallChatNav show: #SmallChatTsNav method: #renameSymbolAt:line:character:to:` -> shows the exact arguments + LSP semantics.'; lf.
		s nextPutAll: 'Then call SmallChatTsNav renameSymbolAt:... and follow up with diagnosticsFor: on the touched files to confirm they still parse.'; lf; lf.
		s nextPutAll: 'Tool results are plain Markdown. Compose multiple calls when you need to refine an answer. Keep edits scoped; one symbol per turn is safer than a batch.' ]
]

{ #category : 'accessing' }
SmallChatTsWorkspace class >> kind [ ^ #ts
]

{ #category : 'accessing' }
SmallChatTsWorkspace class >> launcherBlock [
	"Block (path -> SmallChatLSPClient) used to launch tsgo on attach. Tests
	 swap this for a stub that returns a stub-transport client. Default spawns
	 real tsgo via SmallChatLSPClient class>>launchTsgoForWorkspace: which
	 resolves the workspace-local binary, runs the initialize handshake, and
	 returns a live client."
	^ LauncherBlock ifNil: [ [ :path | SmallChatLSPClient launchTsgoForWorkspace: path ] ]
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

{ #category : 'famix' }
SmallChatTsWorkspace >> reimportUri: aUri text: aText [
	"Drop and re-import a single URI in the cached Famix model so writes
	 (TsNav writeFile:, rename success, code-action apply) keep the
	 in-memory model aligned with the on-disk file. No-op when the model
	 has not been built yet -- the next famixModel call will pick up the
	 fresh disk state via the project-wide walk."
	famixModel ifNil: [ ^ self ].
	self famixImporter
		reimportUris: (Dictionary new at: aUri put: aText; yourself).
	^ self
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
