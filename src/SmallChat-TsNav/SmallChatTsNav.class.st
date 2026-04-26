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
	^ self renderPathList: (self relativePathsInWorkspace: aWs matching: aGlob)
]

{ #category : 'discovery' }
SmallChatTsNav class >> findSymbol: aPattern [
	"Markdown table of Famix entities whose name matches aPattern (regex
	 semantics, mirrors SmallChatNav). Walks Class, Interface, Function,
	 Method, Field, TypeAlias, JSXComponent, CSSClass. Each row reports
	 the workspace-relative file plus the LSP-compatible line:character of
	 the entity's declaration anchor -- ready to feed into
	 renameSymbolInFile:line:character:to:."
	^ self withWorkspaceDo: [ :ws | self findSymbol: aPattern inWorkspace: ws ]
]

{ #category : 'private' }
SmallChatTsNav class >> findSymbol: aPattern inWorkspace: aWs [
	| model matcher entityTypes matches |
	model := aWs famixModel.
	matcher := RxMatcher forString: aPattern.
	entityTypes := {
		SmallChatFamixClass.
		SmallChatFamixInterface.
		SmallChatFamixFunction.
		SmallChatFamixMethod.
		SmallChatFamixField.
		SmallChatFamixTypeAlias.
		SmallChatFamixJSXComponent.
		SmallChatFamixCSSClass }.
	matches := OrderedCollection new.
	entityTypes do: [ :type |
		(model allWithType: type) do: [ :e |
			(e name notNil and: [ matcher search: e name ])
				ifTrue: [ matches add: e ] ] ].
	^ self renderSymbolMatches: matches inWorkspace: aWs
]

{ #category : 'discovery' }
SmallChatTsNav class >> grep: aPattern in: aGlob [
	"Regex-search the Famix-known files matching aGlob; render rows as
	 `path:line: text`. Lines are read through the workspace path so memory-
	 FS fixtures work. Per-file capping happens through SmallChatNavBudget on
	 the rendered output."
	^ self withWorkspaceDo: [ :ws | self grep: aPattern in: aGlob inWorkspace: ws ]
]

{ #category : 'private' }
SmallChatTsNav class >> grep: aPattern in: aGlob inWorkspace: aWs [
	| matcher rels results |
	matcher := RxMatcher forString: aPattern.
	rels := self relativePathsInWorkspace: aWs matching: aGlob.
	results := OrderedCollection new.
	rels do: [ :rel |
		| file text |
		file := aWs path / rel.
		file exists ifTrue: [
			text := file readStreamDo: [ :s | s upToEnd ].
			text lines withIndexDo: [ :line :lineNo |
				(matcher search: line) ifTrue: [
					results add: { rel. lineNo. line trimRight } ] ] ] ].
	^ self renderGrepResults: results
]

{ #category : 'private' }
SmallChatTsNav class >> kindLabelFor: anEntity [
	"Human-friendly entity-kind label derived from the SmallChatFamix class
	 name -- 'class', 'interface', 'cssclass', etc."
	^ (anEntity className withoutPrefix: 'SmallChatFamix') asLowercase
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

{ #category : 'private' }
SmallChatTsNav class >> positionAtByte: aByte fileUri: aUri inWorkspace: aWs [
	"Convert a Famix UTF-8 byte offset to an LSP {line, character} position.
	 Reads the source through the workspace path so memory-FS fixtures work.
	 Returns 0 @ 0 when the file is missing -- the fallback keeps rendering
	 sane on a stale Famix model."
	| rel file text range |
	rel := self relativePathFor: aUri inWorkspace: aWs.
	file := aWs path / rel.
	file exists ifFalse: [ ^ 0 @ 0 ].
	text := file readStreamDo: [ :s | s upToEnd ].
	range := SmallChatTSRange startByte: aByte endByte: aByte source: text.
	^ range startLine @ range startCharacter
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
SmallChatTsNav class >> relativePathsInWorkspace: aWs matching: aGlob [
	"Workspace-relative paths from the Famix model whose tail matches aGlob.
	 Shared by findFiles: (rendering) and grep:in: (scoping)."
	| model uris matcher paths |
	model := aWs famixModel.
	uris := Set new.
	(model allWithType: SmallChatFamixModule) do: [ :m | uris add: m sourceAnchor fileUri ].
	(model allWithType: SmallChatFamixCSSModuleFile) do: [ :m | uris add: m sourceAnchor fileUri ].
	matcher := RxMatcher forString: (self regexForGlob: aGlob).
	paths := (uris collect: [ :u | self relativePathFor: u inWorkspace: aWs ]) asSortedCollection asArray.
	^ paths select: [ :p | matcher matches: p ]
]

{ #category : 'private' }
SmallChatTsNav class >> renderGrepResults: triples [
	triples isEmpty ifTrue: [ ^ '_no matches_' ].
	^ String streamContents: [ :s | | shown limit |
		shown := 0.
		limit := SmallChatNavBudget default size.
		triples do: [ :triple |
			s position < limit ifTrue: [
				s nextPutAll: '`'; nextPutAll: triple first;
				  nextPutAll: ':'; print: triple second;
				  nextPutAll: '`: '; nextPutAll: triple third; lf.
				shown := shown + 1 ] ].
		shown < triples size ifTrue: [
			s nextPutAll: '_'; print: triples size;
			  nextPutAll: ' matches; showing first '; print: shown;
			  nextPutAll: '._'; lf ] ]
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

{ #category : 'private' }
SmallChatTsNav class >> renderSymbolMatches: matches inWorkspace: aWs [
	matches isEmpty ifTrue: [ ^ '_no symbol matches_' ].
	^ String streamContents: [ :s |
		s nextPutAll: '| name | kind | location |'; lf;
		  nextPutAll: '| --- | --- | --- |'; lf.
		matches do: [ :e |
			| anchor relPath pos |
			anchor := e sourceAnchor.
			relPath := self relativePathFor: anchor fileUri inWorkspace: aWs.
			pos := self positionAtByte: anchor startByte fileUri: anchor fileUri inWorkspace: aWs.
			s nextPutAll: '| `'; nextPutAll: e name; nextPutAll: '` | ';
			  nextPutAll: (self kindLabelFor: e); nextPutAll: ' | `';
			  nextPutAll: relPath; nextPutAll: ':'; print: pos x;
			  nextPutAll: ':'; print: pos y; nextPutAll: '` |'; lf ] ]
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

{ #category : 'editing' }
SmallChatTsNav class >> writeFile: aRelPath contents: aString [
	"Overwrite the workspace-relative file at aRelPath with aString. Notifies
	 the LSP client via textDocument/didChange when the document is open and
	 reimports the URI into the cached Famix model so the next findSymbol:
	 reflects the new content. Returns a one-line confirmation."
	^ self withWorkspaceDo: [ :ws | self writeFile: aRelPath contents: aString inWorkspace: ws ]
]

{ #category : 'private' }
SmallChatTsNav class >> writeFile: aRelPath contents: aString inWorkspace: aWs [
	| file uri client |
	file := aWs path / aRelPath.
	file ensureDelete.
	file writeStreamDo: [ :s | s nextPutAll: aString ].
	uri := 'file://' , file fullName.
	client := aWs lspClient.
	(client notNil and: [ client documentCache isOpen: uri ])
		ifTrue: [ client changeDocumentUri: uri text: aString ].
	aWs reimportUri: uri text: aString.
	^ 'wrote ' , aString size printString , ' bytes to ' , aRelPath
]
