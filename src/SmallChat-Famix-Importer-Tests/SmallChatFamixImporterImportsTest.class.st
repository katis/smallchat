Class {
	#name : 'SmallChatFamixImporterImportsTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

{ #category : 'tests' }
SmallChatFamixImporterImportsTest >> testImportsFromTextEmitsOneImportForSimpleReactImport [
  "Walking the tree-sitter AST of `import React from ''react'';` must emit
   one SmallChatFamixImport whose name is the module specifier (the string
   between the quotes) and whose source anchor covers the whole import_statement
   byte range."
  | model importer text uri imp |
  model := SmallChatFamixModel new.
  importer := SmallChatFamixImporter new
    model: model
    client: nil
    parser: SmallChatTSParser new
    walker: SmallChatTSNodeWalker new.
  text := 'import React from ''react'';'.
  uri := 'file:///t/Foo.tsx'.
  importer populateImportsFromText: text intoUri: uri.
  self assert: (model allWithType: SmallChatFamixImport) size equals: 1.
  imp := (model allWithType: SmallChatFamixImport) first.
  self assert: imp name equals: 'react'.
  self assert: imp sourceAnchor fileUri equals: uri.
  self assert: imp sourceAnchor startByte equals: 0.
  self assert: imp sourceAnchor endByte equals: text size
]
