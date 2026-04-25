Class {
	#name : 'SmallChatFamixImporterDocumentSymbolTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

{ #category : 'helpers' }
SmallChatFamixImporterDocumentSymbolTest >> lspRangeStartLine: sl character: sc endLine: el character: ec [
  ^ Dictionary new
    at: 'start' put: (Dictionary new
      at: 'line' put: sl;
      at: 'character' put: sc;
      yourself);
    at: 'end' put: (Dictionary new
      at: 'line' put: el;
      at: 'character' put: ec;
      yourself);
    yourself
]

{ #category : 'helpers' }
SmallChatFamixImporterDocumentSymbolTest >> newImporterOn: aModel [
  ^ SmallChatFamixImporter new
    model: aModel
    client: nil
    parser: nil
    walker: nil
]

{ #category : 'helpers' }
SmallChatFamixImporterDocumentSymbolTest >> symbolNamed: aName kind: aKind range: aRange [
  ^ Dictionary new
    at: 'name' put: aName;
    at: 'kind' put: aKind;
    at: 'range' put: aRange;
    yourself
]

{ #category : 'tests - kinds' }
SmallChatFamixImporterDocumentSymbolTest >> testCreatesClassFromTopLevelSymbol [
  "Plain top-level `class Button {}` -- LSP SymbolKind 5 maps to
   SmallChatFamixClass with name from the symbol and a source anchor
   covering the symbol's range bytes."
  | model importer text symbol uri famixClass anchor |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'class Button {}'.
  uri := 'file:///test/Button.ts'.
  symbol := self
    symbolNamed: 'Button'
    kind: 5
    range: (self lspRangeStartLine: 0 character: 0 endLine: 0 character: 15).
  importer
    populateFromDocumentSymbols: { symbol }
    intoUri: uri
    text: text.
  self assert: (model allWithType: SmallChatFamixClass) size equals: 1.
  famixClass := (model allWithType: SmallChatFamixClass) first.
  self assert: famixClass name equals: 'Button'.
  anchor := famixClass sourceAnchor.
  self assert: anchor fileUri equals: uri.
  self assert: anchor startByte equals: 0.
  self assert: anchor endByte equals: 15
]

{ #category : 'tests - kinds' }
SmallChatFamixImporterDocumentSymbolTest >> testCreatesFunctionFromTopLevelSymbol [
  "LSP SymbolKind 12 (Function) -> SmallChatFamixFunction."
  | model importer text symbol fn |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'function greet() {}'.
  symbol := self
    symbolNamed: 'greet'
    kind: 12
    range: (self lspRangeStartLine: 0 character: 0 endLine: 0 character: 19).
  importer
    populateFromDocumentSymbols: { symbol }
    intoUri: 'file:///t/g.ts'
    text: text.
  self assert: (model allWithType: SmallChatFamixFunction) size equals: 1.
  fn := (model allWithType: SmallChatFamixFunction) first.
  self assert: fn name equals: 'greet'.
  self assert: fn sourceAnchor endByte equals: 19
]

{ #category : 'tests - kinds' }
SmallChatFamixImporterDocumentSymbolTest >> testCreatesInterfaceFromTopLevelSymbol [
  "LSP SymbolKind 11 (Interface) -> SmallChatFamixInterface."
  | model importer text symbol iface |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'interface IUser {}'.
  symbol := self
    symbolNamed: 'IUser'
    kind: 11
    range: (self lspRangeStartLine: 0 character: 0 endLine: 0 character: 18).
  importer
    populateFromDocumentSymbols: { symbol }
    intoUri: 'file:///t/IUser.ts'
    text: text.
  self assert: (model allWithType: SmallChatFamixInterface) size equals: 1.
  iface := (model allWithType: SmallChatFamixInterface) first.
  self assert: iface name equals: 'IUser'
]

{ #category : 'tests - module' }
SmallChatFamixImporterDocumentSymbolTest >> testImportTsFileCreatesModulePerFile [
  "Per-file importer must emit one SmallChatFamixModule per imported URI, with
   the module name derived from the URI's last path segment and a source anchor
   covering the whole text."
  | model importer text uri symbols modules module |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'class Button {}'.
  uri := 'file:///t/Button.ts'.
  symbols := { self
    symbolNamed: 'Button'
    kind: 5
    range: (self lspRangeStartLine: 0 character: 0 endLine: 0 character: 15) }.
  importer
    populateFromDocumentSymbols: symbols
    intoUri: uri
    text: text.
  modules := model allWithType: SmallChatFamixModule.
  self assert: modules size equals: 1.
  module := modules first.
  self assert: module name equals: 'Button.ts'.
  self assert: module sourceAnchor fileUri equals: uri.
  self assert: module sourceAnchor startByte equals: 0.
  self assert: module sourceAnchor endByte equals: text size
]

{ #category : 'tests - kinds' }
SmallChatFamixImporterDocumentSymbolTest >> testNestedConstructorEmitsMethodWithOwningClass [
  "LSP SymbolKind 9 (Constructor) folds into SmallChatFamixMethod -- v1
   doesn't carry an isConstructor flag (deferred per S6 / plan 03 Â§non-goals)."
  | model importer text classSym ctorSym method |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'class Greeter { constructor() {} }'.
  ctorSym := self
    symbolNamed: 'constructor'
    kind: 9
    range: (self lspRangeStartLine: 0 character: 16 endLine: 0 character: 32).
  classSym := (self
    symbolNamed: 'Greeter'
    kind: 5
    range: (self lspRangeStartLine: 0 character: 0 endLine: 0 character: 34))
    at: 'children' put: { ctorSym };
    yourself.
  importer
    populateFromDocumentSymbols: { classSym }
    intoUri: 'file:///t/Greeter.ts'
    text: text.
  self assert: (model allWithType: SmallChatFamixMethod) size equals: 1.
  method := (model allWithType: SmallChatFamixMethod) first.
  self assert: method name equals: 'constructor'.
  self assert: method owningClass equals: (model allWithType: SmallChatFamixClass) first
]

{ #category : 'tests - nesting' }
SmallChatFamixImporterDocumentSymbolTest >> testNestedMethodLinksToOwningClass [
  "A Class with a nested Method DocumentSymbol child should produce a
   SmallChatFamixClass and a SmallChatFamixMethod, with the method's
   owningClass slot pointing back at the class."
  | model importer text classSym methodSym famixClass method |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'class Greeter { greet() {} }'.
  methodSym := self
    symbolNamed: 'greet'
    kind: 6
    range: (self lspRangeStartLine: 0 character: 16 endLine: 0 character: 26).
  classSym := (self
    symbolNamed: 'Greeter'
    kind: 5
    range: (self lspRangeStartLine: 0 character: 0 endLine: 0 character: 28))
    at: 'children' put: { methodSym };
    yourself.
  importer
    populateFromDocumentSymbols: { classSym }
    intoUri: 'file:///t/Greeter.ts'
    text: text.
  self assert: (model allWithType: SmallChatFamixClass) size equals: 1.
  self assert: (model allWithType: SmallChatFamixMethod) size equals: 1.
  famixClass := (model allWithType: SmallChatFamixClass) first.
  method := (model allWithType: SmallChatFamixMethod) first.
  self assert: method name equals: 'greet'.
  self assert: method owningClass identicalTo: famixClass.
  self assert: method sourceAnchor startByte equals: 16.
  self assert: method sourceAnchor endByte equals: 26
]

{ #category : 'tests - kinds' }
SmallChatFamixImporterDocumentSymbolTest >> testNestedPropertyEmitsField [
  "LSP SymbolKind 7 (Property) -- fires for class fields, interface members,
   object-literal keys -- maps to SmallChatFamixField (one entity, no Property
   distinction in v1 per S6)."
  | model importer text classSym propSym field |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'class Box { width = 0 }'.
  propSym := self
    symbolNamed: 'width'
    kind: 7
    range: (self lspRangeStartLine: 0 character: 12 endLine: 0 character: 21).
  classSym := (self
    symbolNamed: 'Box'
    kind: 5
    range: (self lspRangeStartLine: 0 character: 0 endLine: 0 character: 23))
    at: 'children' put: { propSym };
    yourself.
  importer
    populateFromDocumentSymbols: { classSym }
    intoUri: 'file:///t/Box.ts'
    text: text.
  self assert: (model allWithType: SmallChatFamixField) size equals: 1.
  field := (model allWithType: SmallChatFamixField) first.
  self assert: field name equals: 'width'
]

{ #category : 'tests - kinds' }
SmallChatFamixImporterDocumentSymbolTest >> testUnknownSymbolKindIsSilentlySkipped [
  "Variable / Namespace / Constant / TypeParameter etc. are routed through
   tree-sitter (or skipped). The walker must skip the symbol entirely *and*
   not crash, but still recurse into children -- nested known kinds inside an
   ignored Variable still get picked up."
  | model importer varSym text |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'const x = 1'.
  varSym := self
    symbolNamed: 'x'
    kind: 13
    range: (self lspRangeStartLine: 0 character: 0 endLine: 0 character: 11).
  importer
    populateFromDocumentSymbols: { varSym }
    intoUri: 'file:///t/x.ts'
    text: text.
  self assert: (model allWithType: SmallChatFamixEntity) size equals: 0
]
