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
