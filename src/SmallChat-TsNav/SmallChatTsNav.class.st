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
	"Bullet list of workspace-relative paths whose tail matches aGlob.
	 Reads SmallChatFamixModule + SmallChatFamixCSSModuleFile entities from
	 the lazy Famix model. Glob semantics: * matches any sequence (including
	 path separators), ? matches one character; everything else is literal."
	^ self withWorkspaceDo: [ :ws | self findFilesInWorkspace: ws matching: aGlob ]
]

{ #category : 'private' }
SmallChatTsNav class >> findFilesInWorkspace: aWs matching: aGlob [
	| model uris paths matcher matches |
	model := aWs famixModel.
	uris := Set new.
	(model allWithType: SmallChatFamixModule) do: [ :m | uris add: m sourceAnchor fileUri ].
	(model allWithType: SmallChatFamixCSSModuleFile) do: [ :m | uris add: m sourceAnchor fileUri ].
	paths := (uris collect: [ :u | self relativePathFor: u inWorkspace: aWs ]) asSortedCollection asArray.
	matcher := RxMatcher forString: (self regexForGlob: aGlob).
	matches := paths select: [ :p | matcher matches: p ].
	^ self renderPathList: matches
]

{ #category : 'private' }
SmallChatTsNav class >> languageIdForPath: aRelPath [
	"Code-fence language hint for aRelPath. Mirrors the LSP languageId map
	 so a TS reader and a TS rename land on the same language identifier."
	(aRelPath endsWith: '.tsx') ifTrue: [ ^ 'tsx' ].
	(aRelPath endsWith: '.ts') ifTrue: [ ^ 'typescript' ].
	(aRelPath endsWith: '.jsx') ifTrue: [ ^ 'jsx' ].
	(aRelPath endsWith: '.js') ifTrue: [ ^ 'javascript' ].
	(aRelPath endsWith: '.module.css') ifTrue: [ ^ 'css' ].
	(aRelPath endsWith: '.css') ifTrue: [ ^ 'css' ].
	(aRelPath endsWith: '.json') ifTrue: [ ^ 'json' ].
	(aRelPath endsWith: '.md') ifTrue: [ ^ 'markdown' ].
	^ 'text'
]

{ #category : 'discovery' }
SmallChatTsNav class >> readFile: aRelPath [
	"Fenced content of the workspace-relative file at aRelPath. Reads via
	 the file's own FileSystem so memory-FS fixtures work too. Missing
	 file -> friendly Markdown stub. Output capped by SmallChatNavBudget;
	 truncation includes a tail comment so the LM knows to narrow."
	^ self withWorkspaceDo: [ :ws | self readFile: aRelPath inWorkspace: ws ]
]

{ #category : 'private' }
SmallChatTsNav class >> readFile: aRelPath inWorkspace: aWs [
	| file content lang body limit |
	file := aWs path / aRelPath.
	file exists ifFalse: [ ^ '_file not found: ' , aRelPath , '_' ].
	content := file readStreamDo: [ :s | s upToEnd ].
	lang := self languageIdForPath: aRelPath.
	limit := SmallChatNavBudget default size.
	body := content size > limit
		ifTrue: [ (content copyFrom: 1 to: limit) , String lf , '... [truncated; ' , content size printString , ' bytes total]' ]
		ifFalse: [ content ].
	^ String streamContents: [ :s |
		s nextPutAll: '```'; nextPutAll: lang; lf;
		  nextPutAll: body;
		  lf; nextPutAll: '```'; lf ]
]

{ #category : 'private' }
SmallChatTsNav class >> regexForGlob: aGlob [
	"Convert a simple glob (*, ?, literal) to an anchored Pharo RxMatcher
	 source. * spans path separators -- callers wanting per-segment matching
	 can pass narrower globs."
	^ String streamContents: [ :s |
		s nextPutAll: '^'.
		aGlob do: [ :c |
			c = $* ifTrue: [ s nextPutAll: '.*' ] ifFalse: [
				c = $? ifTrue: [ s nextPut: $. ] ifFalse: [
					('.+()|^${}[]\' includes: c)
						ifTrue: [ s nextPut: $\; nextPut: c ]
						ifFalse: [ s nextPut: c ] ] ] ].
		s nextPutAll: '$' ]
]

{ #category : 'private' }
SmallChatTsNav class >> relativePathFor: aUri inWorkspace: aWs [
	"Strip the workspace-root prefix from aUri so output is short + portable.
	 URIs from outside the root (rare; happens for cross-package imports the
	 Famix model has resolved) come back unchanged."
	| rootPrefix |
	rootPrefix := 'file://' , aWs path fullName , '/'.
	^ (aUri beginsWith: rootPrefix)
		ifTrue: [ aUri copyFrom: rootPrefix size + 1 to: aUri size ]
		ifFalse: [ aUri ]
]

{ #category : 'private' }
SmallChatTsNav class >> renderPathList: paths [
	"Bullet list of paths capped by SmallChatNavBudget default size; tail
	 line summarises the truncation."
	| limit |
	paths isEmpty ifTrue: [ ^ '_no matches_' ].
	limit := SmallChatNavBudget default size.
	^ String streamContents: [ :s | | shown |
		shown := 0.
		paths do: [ :p |
			s position < limit ifTrue: [
				s nextPutAll: '* `'; nextPutAll: p; nextPutAll: '`'; lf.
				shown := shown + 1 ] ].
		shown < paths size ifTrue: [
			s nextPutAll: '_'; print: paths size;
			  nextPutAll: ' matches; showing first '; print: shown;
			  nextPutAll: '._'; lf ] ]
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
