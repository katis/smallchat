"
Class-side discovery + edit API for chat sessions bound to a TypeScript workspace. Mirrors the SmallChatNav pattern: every selector returns budgeted Markdown via SmallChatNavBudget default size. Discovery (findFiles:, findSymbol:, findReferencesOf:, grep:in:) reads from the workspace's lazy Famix model. Mutations + live diagnostics (writeFile:contents:, diagnosticsFor:, renameSymbolInFile:..., codeActionsAt:..., applyCodeAction:) drive the workspace's LSP client. The workspace is bound per evaluate call by SmallChatEvalSmalltalkCapability.
"
Class {
	#name : 'SmallChatTsNav',
	#superclass : 'Object',
	#classInstVars : [
		'currentWorkspace',
		'lastCodeActions'
	],
	#category : 'SmallChat-TsNav',
	#package : 'SmallChat-TsNav'
}

{ #category : 'workspace binding' }
SmallChatTsNav class >> currentWorkspace [
	"The TS workspace this evaluate call is operating against. Set by
	 SmallChatEvalSmalltalkCapability around each run: so SmallChatTsNav
	 selectors do not need an explicit workspace argument. Returns nil
	 when unbound -- callers render the friendly Markdown guard."
	^ currentWorkspace
]

{ #category : 'workspace binding' }
SmallChatTsNav class >> currentWorkspace: aTsWorkspaceOrNil [
	"Bind the active workspace for the duration of one evaluate call. Pass
	 nil to clear; SmallChatEvalSmalltalkCapability does this in #ensure:
	 so a subsequent Pharo eval does not see a stale TS binding."
	currentWorkspace := aTsWorkspaceOrNil
]

{ #category : 'discovery' }
SmallChatTsNav class >> findFiles: aGlob [
	"Bullet list of workspace-relative paths matching aGlob. Reads from
	 the lazy Famix model -- first call walks the project, subsequent
	 calls are in-memory. Placeholder body until the glob filter lands."
	^ self withWorkspaceDo: [ :ws | '' ]
]

{ #category : 'workspace binding' }
SmallChatTsNav class >> withWorkspaceDo: aOneArgBlock [
	"Run aOneArgBlock with the bound TS workspace, or short-circuit with
	 the friendly Markdown guard when no workspace is bound. Every public
	 selector funnels through this so the guard message is identical."
	currentWorkspace ifNil: [
		^ '_no TS workspace bound -- open or attach a TS workspace first_' ].
	^ aOneArgBlock value: currentWorkspace
]
