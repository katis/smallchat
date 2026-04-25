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

{ #category : 'symbol mapping' }
SmallChatFamixImporter >> entityForSymbol: aSymbol ifAbsent: aBlock [
  | factory |
  factory := self symbolKindFactories at: (aSymbol at: 'kind') ifAbsent: [ ^ aBlock value ].
  ^ factory value: model
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
   range against aText."
  aSymbolList do: [ :sym | self processSymbol: sym intoUri: aUri text: aText owner: nil ]
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
