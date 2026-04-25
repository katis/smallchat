Class {
	#name : 'SmallChatFamixImporter',
	#superclass : 'Object',
	#instVars : [
		'model',
		'client',
		'parser',
		'walker'
	],
	#category : 'SmallChat-Famix-Importer',
	#package : 'SmallChat-Famix-Importer'
}

{ #category : 'classification' }
SmallChatFamixImporter class >> classifyResolvedUri: aResolvedUri againstRoot: aRootUri [
  "Bucket a textDocument/definition resolution into one of:
   #unresolved (nil or empty), #nodeModules (node_modules anywhere on the
   path -- check before #srcLocal because node_modules typically lives
   inside the project root), #srcLocal (under aRootUri),
   #virtualModule (resolved but outside the project root and not in
   node_modules; covers Cloudflare cloudflare:workers and similar virtual
   specifiers per S6)."
  (aResolvedUri isNil or: [ aResolvedUri isEmpty ])
    ifTrue: [ ^ #unresolved ].
  (aResolvedUri includesSubstring: 'node_modules/')
    ifTrue: [ ^ #nodeModules ].
  (aRootUri notNil and: [ aResolvedUri beginsWith: aRootUri ])
    ifTrue: [ ^ #srcLocal ].
  ^ #virtualModule
]

{ #category : 'symbol mapping' }
SmallChatFamixImporter >> anchorForSymbol: aSymbol uri: aUri text: aText [
  | range |
  range := SmallChatTSRange fromLSPPositionRange: (aSymbol at: 'range') source: aText.
  ^ SmallChatFamixSourceAnchor
    fileUri: aUri
    startByte: range startByte
    endByte: range endByte
]

{ #category : 'accessing' }
SmallChatFamixImporter >> client [ ^ client
]

{ #category : 'population' }
SmallChatFamixImporter >> ensureModuleForUri: aUri text: aText [
  "Create a SmallChatFamixModule for aUri, linked to the model's singleton
   Project. Module name is the URI's last path segment (the bare filename);
   source anchor covers the whole text. Caller is responsible for not
   double-importing a URI -- regeneration (S5) adds the de-dup pass."
  | filename module |
  filename := aUri copyAfterLast: $/.
  module := model newModule.
  module name: filename.
  module project: self ensureProject.
  module sourceAnchor: (SmallChatFamixSourceAnchor
    fileUri: aUri
    startByte: 0
    endByte: aText size).
  ^ module
]

{ #category : 'population' }
SmallChatFamixImporter >> ensureProject [
  "Return the singleton SmallChatFamixProject for this model, creating it on
   first call. One project per model -- workspace identity flows from the model
   the importer was constructed with."
  | existing |
  existing := model allWithType: SmallChatFamixProject.
  existing isEmpty ifFalse: [ ^ existing first ].
  ^ model newProject
]

{ #category : 'symbol mapping' }
SmallChatFamixImporter >> entityForSymbol: aSymbol ifAbsent: aBlock [
  | factory |
  factory := self symbolKindFactories at: (aSymbol at: 'kind') ifAbsent: [ ^ aBlock value ].
  ^ factory value: model
]

{ #category : 'orchestration' }
SmallChatFamixImporter >> fetchDocumentSymbolsForUri: aUri [
  "Issue textDocument/documentSymbol for an already-open URI; returns the
   server's result list (or empty when the server returns nil)."
  | response |
  response := client
    request: (Dictionary new
      at: 'method' put: 'textDocument/documentSymbol';
      at: 'params' put: (Dictionary new
        at: 'textDocument' put: (Dictionary new at: 'uri' put: aUri; yourself);
        yourself);
      yourself)
    onDocumentUri: aUri.
  ^ response ifNil: [ #() ]
]

{ #category : 'orchestration' }
SmallChatFamixImporter >> importTsFileUri: aUri text: aText [
  "Open aUri on the LSP client (so subsequent requests pre-flight cleanly),
   fetch documentSymbol, and turn the response into Famix entities. Then walk
   tree-sitter for imports and JSX components. Blocking on the LSP pending;
   callers must not run on the UI process. The text-injecting form keeps tests
   off disk."
  | symbols |
  client openDocumentUri: aUri languageId: (self languageIdForUri: aUri) text: aText.
  symbols := self fetchDocumentSymbolsForUri: aUri.
  self populateFromDocumentSymbols: symbols intoUri: aUri text: aText.
  self populateImportsFromText: aText intoUri: aUri.
  self populateJsxComponentsFromText: aText intoUri: aUri
]

{ #category : 'orchestration' }
SmallChatFamixImporter >> languageIdForUri: aUri [
  "Map a file URI suffix to the LSP languageId server expects."
  (aUri endsWith: '.tsx') ifTrue: [ ^ 'typescriptreact' ].
  (aUri endsWith: '.ts') ifTrue: [ ^ 'typescript' ].
  (aUri endsWith: '.js') ifTrue: [ ^ 'javascript' ].
  (aUri endsWith: '.jsx') ifTrue: [ ^ 'javascriptreact' ].
  ^ 'typescript'
]

{ #category : 'accessing' }
SmallChatFamixImporter >> model [ ^ model
]

{ #category : 'initialization' }
SmallChatFamixImporter >> model: aModel client: aClient parser: aParser walker: aWalker [
  model := aModel.
  client := aClient.
  parser := aParser.
  walker := aWalker.
  ^ self
]

{ #category : 'accessing' }
SmallChatFamixImporter >> parser [ ^ parser
]

{ #category : 'population' }
SmallChatFamixImporter >> populateFromDocumentSymbols: aSymbolList intoUri: aUri text: aText [
  "Walk a hierarchical DocumentSymbol[] response, creating one Famix entity per
   recognised SymbolKind. Source anchors are bytes derived from the LSP UTF-16
   range against aText. Emits one SmallChatFamixModule per URI as the file-level
   container; symbol entities use the same URI in their own anchors so queries
   can find them by file."
  self ensureModuleForUri: aUri text: aText.
  aSymbolList do: [ :sym | self processSymbol: sym intoUri: aUri text: aText owner: nil ]
]

{ #category : 'population' }
SmallChatFamixImporter >> populateImportsFromText: aText intoUri: aUri [
  "Parse aText with the TSX grammar, walk import_statements, and emit one
   SmallChatFamixImport per top-level import. Entity name is the module
   specifier (the string between the quotes); sourceAnchor covers the whole
   import_statement byte range."
  | tree specs |
  tree := parser parseTsxString: aText.
  specs := walker importSpecifiersIn: tree rootNode source: aText.
  specs do: [ :spec | | imp |
    imp := model newImport.
    imp name: (spec at: 'specifier').
    imp sourceAnchor: (SmallChatFamixSourceAnchor
      fileUri: aUri
      startByte: (spec at: 'startByte')
      endByte: (spec at: 'endByte')) ]
]

{ #category : 'population' }
SmallChatFamixImporter >> populateJsxComponentsFromText: aText intoUri: aUri [
  "Parse aText with the TSX grammar, walk for JSXComponent declarations
   (top-level function declarations / const-arrows / TanStack pair-arrows
   that return JSX), and emit one SmallChatFamixJSXComponent per detection.
   Source anchor covers the whole declaration."
  | tree decls |
  tree := parser parseTsxString: aText.
  decls := walker jsxComponentDeclarationsIn: tree rootNode source: aText.
  decls do: [ :d | | comp |
    comp := model newJSXComponent.
    comp name: (d at: 'name').
    comp sourceAnchor: (SmallChatFamixSourceAnchor
      fileUri: aUri
      startByte: (d at: 'startByte')
      endByte: (d at: 'endByte')) ]
]

{ #category : 'symbol mapping' }
SmallChatFamixImporter >> processSymbol: aSymbol intoUri: aUri text: aText owner: anOwner [
  "Convert one DocumentSymbol (and recursively its children) into Famix
   entities. anOwner is the enclosing entity for nested symbols (Class -> Method,
   Class -> Field, etc.)."
  | entity |
  entity := self entityForSymbol: aSymbol ifAbsent: [ nil ].
  entity ifNotNil: [
    entity name: (aSymbol at: 'name').
    entity sourceAnchor: (self anchorForSymbol: aSymbol uri: aUri text: aText).
    ((entity isKindOf: SmallChatFamixMethod) and: [ anOwner notNil and: [ anOwner isKindOf: SmallChatFamixClass ] ])
      ifTrue: [ entity owningClass: anOwner ] ].
  (aSymbol at: 'children' ifAbsent: [ #() ]) do: [ :child |
    self processSymbol: child intoUri: aUri text: aText owner: (entity ifNil: [ anOwner ]) ]
]

{ #category : 'symbol mapping' }
SmallChatFamixImporter >> symbolKindFactories [
  "LSP SymbolKind -> block taking a SmallChatFamixModel and returning a fresh
   entity already added to the model. Variable (13) / Namespace (23) / Constant (14)
   are intentionally absent -- per S6 we route Variable through tree-sitter to
   JSXComponent, and Namespace / Constant defer until something asks."
  ^ Dictionary new
    at: 5  put: [ :m | m newClass ];
    at: 6  put: [ :m | m newMethod ];
    at: 7  put: [ :m | m newField ];
    at: 8  put: [ :m | m newField ];
    at: 9  put: [ :m | m newMethod ];
    at: 11 put: [ :m | m newInterface ];
    at: 12 put: [ :m | m newFunction ];
    yourself
]

{ #category : 'accessing' }
SmallChatFamixImporter >> walker [ ^ walker
]
