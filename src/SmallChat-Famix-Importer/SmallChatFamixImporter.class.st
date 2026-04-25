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

{ #category : 'orchestration' }
SmallChatFamixImporter >> bindingNameFor: aSpecifier inRootNode: aRootNode source: aText [
  "Find the default-import binding name for a given specifier in aText:
   walk import_statements, locate the one whose string_fragment equals
   aSpecifier, and read the import_clause > identifier text. Returns nil
   if the matching import has no default-import identifier (e.g. named-
   only `import { x } from 'mod'`)."
  | importStatements |
  importStatements := walker importStatements: aRootNode.
  importStatements do: [ :imp | | sourceString fragment importClause idChild |
    sourceString := imp namedChildren detect: [ :c | c type = 'string' ] ifNone: [ nil ].
    sourceString ifNotNil: [
      fragment := sourceString namedChildren first.
      (fragment textFromSourceText: aText) = aSpecifier ifTrue: [
        importClause := imp namedChildren detect: [ :c | c type = 'import_clause' ] ifNone: [ nil ].
        importClause ifNotNil: [
          idChild := importClause namedChildren detect: [ :c | c type = 'identifier' ] ifNone: [ nil ].
          idChild ifNotNil: [ ^ idChild textFromSourceText: aText ] ] ] ] ].
  ^ nil
]

{ #category : 'accessing' }
SmallChatFamixImporter >> client [ ^ client
]

{ #category : 'regeneration' }
SmallChatFamixImporter >> dropEntitiesForUri: aUri [
  "Remove every entity from the model whose sourceAnchor fileUri equals
   aUri. Entities without a sourceAnchor (Project) are left alone."
  | doomed |
  doomed := model entities select: [ :e |
    (e respondsTo: #sourceAnchor)
      and: [ e sourceAnchor notNil
      and: [ e sourceAnchor fileUri = aUri ] ] ].
  model removeAll: doomed
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
SmallChatFamixImporter >> importCssFileUri: aUri text: aText [
  "Parse aUri (must end in .module.css; non-module CSS files are skipped
   per plan 03 entity inventory) with the CSS grammar. Emit one
   SmallChatFamixCSSModuleFile (anchor covers the whole text) and one
   SmallChatFamixCSSClass per UNIQUE class_selector name; the same name
   appearing in multiple rule_sets dedupes to a single entity. Each
   CSSClass carries a file: back-pointer to the SmallChatFamixCSSModuleFile."
  | filename file tree selectors seen |
  (aUri endsWith: '.module.css') ifFalse: [ ^ self ].
  filename := aUri copyAfterLast: $/.
  file := model newCSSModuleFile.
  file name: filename.
  file sourceAnchor: (SmallChatFamixSourceAnchor
    fileUri: aUri
    startByte: 0
    endByte: aText size).
  tree := parser parseCssString: aText.
  selectors := walker classSelectors: tree rootNode.
  seen := Set new.
  selectors do: [ :sel | | nameNode className cssClass |
    nameNode := (sel namedChildren detect: [ :c | c type = 'class_name' ]) namedChildren first.
    className := nameNode textFromSourceText: aText.
    (seen includes: className) ifFalse: [
      seen add: className.
      cssClass := model newCSSClass.
      cssClass name: className.
      cssClass file: file.
      cssClass sourceAnchor: (SmallChatFamixSourceAnchor
        fileUri: aUri
        startByte: sel startByte
        endByte: sel endByte) ] ]
]

{ #category : 'orchestration' }
SmallChatFamixImporter >> importTsFileUri: aUri text: aText [
  "Open aUri on the LSP client (so subsequent requests pre-flight cleanly),
   fetch documentSymbol, populate symbols / imports / JSX from the response
   and tree-sitter, and finally link any styles.X references back to
   pre-imported CSSModuleFile entities. Blocking on the LSP pending; callers
   must not run on the UI process. The text-injecting form keeps tests off
   disk."
  | symbols |
  client openDocumentUri: aUri languageId: (self languageIdForUri: aUri) text: aText.
  symbols := self fetchDocumentSymbolsForUri: aUri.
  self populateFromDocumentSymbols: symbols intoUri: aUri text: aText.
  self populateImportsFromText: aText intoUri: aUri.
  self populateJsxComponentsFromText: aText intoUri: aUri.
  self linkCssReferencesInTsUri: aUri text: aText
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

{ #category : 'orchestration' }
SmallChatFamixImporter >> linkCssReferencesForImportSpec: aSpec inUri: aUri rootNode: aRootNode text: aText [
  "Per-import worker: find the CSSModuleFile via the corresponding Import
   entity's resolvedUri, walk member_expressions for the binding, emit one
   CSSClassReference per access. If the Import or CSSModuleFile is missing,
   skip (the bridge tolerates partial model state)."
  | bindingName imp cssFile cssClasses members |
  bindingName := self bindingNameFor: (aSpec at: 'specifier')
    inRootNode: aRootNode source: aText.
  bindingName ifNil: [ ^ self ].
  imp := (model allWithType: SmallChatFamixImport)
    detect: [ :i | i name = (aSpec at: 'specifier')
      and: [ i sourceAnchor notNil
      and: [ i sourceAnchor fileUri = aUri ] ] ]
    ifNone: [ ^ self ].
  imp resolvedUri ifNil: [ ^ self ].
  cssFile := (model allWithType: SmallChatFamixCSSModuleFile)
    detect: [ :f | f sourceAnchor notNil
      and: [ f sourceAnchor fileUri = imp resolvedUri ] ]
    ifNone: [ ^ self ].
  cssClasses := (model allWithType: SmallChatFamixCSSClass)
    select: [ :c | c file == cssFile ].
  members := walker
    memberExpressionsFor: aRootNode
    objectName: bindingName
    inSource: aText.
  members do: [ :m | | propertyName matched ref |
    propertyName := (m namedChildren second textFromSourceText: aText).
    matched := cssClasses detect: [ :c | c name = propertyName ] ifNone: [ nil ].
    ref := model newCSSClassReference.
    ref name: propertyName.
    ref sourceAnchor: (SmallChatFamixSourceAnchor
      fileUri: aUri
      startByte: m startByte
      endByte: m endByte).
    matched
      ifNotNil: [ ref referent: matched. ref unresolved: false ]
      ifNil: [ ref referent: nil. ref unresolved: true ] ]
]

{ #category : 'orchestration' }
SmallChatFamixImporter >> linkCssReferencesInTsUri: aUri text: aText [
  "Walk aText for CSS-module imports (default import of a .module.css
   specifier), look up each import's resolvedUri (set by S2 resolution)
   to find the SmallChatFamixCSSModuleFile in the model, then emit one
   SmallChatFamixCSSClassReference per `bindingName.X` member_expression.
   Resolved references back-point to the matching SmallChatFamixCSSClass;
   unresolved (typo) references carry referent = nil and unresolved = true.
   Caller is responsible for pre-running CSS import + TS import resolution
   so the model state is in place."
  | tree root specs cssImports |
  tree := parser parseTsxString: aText.
  root := tree rootNode.
  specs := walker importSpecifiersIn: root source: aText.
  cssImports := specs select: [ :spec |
    (spec at: 'specifier') endsWith: '.module.css' ].
  cssImports do: [ :spec | self
    linkCssReferencesForImportSpec: spec
    inUri: aUri
    rootNode: root
    text: aText ]
]

{ #category : 'resolution' }
SmallChatFamixImporter >> lspPositionForByte: aByte inSource: aText [
  "Build an LSP position dict (line + character) for a UTF-8 byte offset
   into aText. Uses SmallChatTSRange's lineCharacterAtByte: -- the byte/
   UTF-16 encoding logic already lives there."
  | range point |
  range := SmallChatTSRange startByte: aByte endByte: aByte source: aText.
  point := range lineCharacterAtByte: aByte.
  ^ Dictionary new
    at: 'line' put: point x;
    at: 'character' put: point y;
    yourself
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
   import_statement byte range. Each Import is then resolved via
   textDocument/definition (resolvedUri + classification populated) -- aUri
   must already be open on the LSP client for this to work."
  | tree specs |
  tree := parser parseTsxString: aText.
  specs := walker importSpecifiersIn: tree rootNode source: aText.
  specs do: [ :spec | | imp |
    imp := model newImport.
    imp name: (spec at: 'specifier').
    imp sourceAnchor: (SmallChatFamixSourceAnchor
      fileUri: aUri
      startByte: (spec at: 'startByte')
      endByte: (spec at: 'endByte')).
    self
      resolveImport: imp
      atSpecifierStartByte: (spec at: 'specifierStartByte')
      inSourceText: aText
      onUri: aUri ]
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

{ #category : 'resolution' }
SmallChatFamixImporter >> resolveImport: anImport atSpecifierStartByte: aByte inSourceText: aText onUri: aUri [
  "Issue textDocument/definition for the import specifier at aByte in aText
   on aUri, set anImport resolvedUri to the first Location's uri (or nil if
   the response is nil/empty), and classify it against the model's project
   rootUri. Tolerates Location | Location[] | LocationLink[] response shapes
   (LSP allows all three); takes the first uri it finds. Blocking on the LSP
   pending; caller must not run on the UI."
  | response location resolvedUri rootUri |
  response := client
    request: (Dictionary new
      at: 'method' put: 'textDocument/definition';
      at: 'params' put: (Dictionary new
        at: 'textDocument' put: (Dictionary new at: 'uri' put: aUri; yourself);
        at: 'position' put: (self lspPositionForByte: aByte inSource: aText);
        yourself);
      yourself)
    onDocumentUri: aUri.
  location := response isNil
    ifTrue: [ nil ]
    ifFalse: [ (response isArray or: [ response isKindOf: SequenceableCollection ])
        ifTrue: [ response isEmpty ifTrue: [ nil ] ifFalse: [ response first ] ]
        ifFalse: [ response ] ].
  resolvedUri := location isNil
    ifTrue: [ nil ]
    ifFalse: [ location at: 'uri' ifAbsent: [ location at: 'targetUri' ifAbsent: [ nil ] ] ].
  anImport resolvedUri: resolvedUri.
  rootUri := (self ensureProject) rootUri.
  anImport classification: (self class
    classifyResolvedUri: resolvedUri
    againstRoot: rootUri)
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
