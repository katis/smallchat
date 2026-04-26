Class {
	#name : 'SmallChatLSPInitializeParamsTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'tests - capabilities' }
SmallChatLSPInitializeParamsTest >> testInitializeParamsForRootRequestsHierarchicalDocumentSymbols [
	"Initialize must opt the client into hierarchical DocumentSymbol so tsgo
	 returns objects with range/selectionRange/children rather than the flat
	 SymbolInformation shape (which carries location and breaks the Famix
	 importer)."
	| params caps docSym |
	params := SmallChatLSPClient initializeParamsForRoot: '/tmp/smallchat-init-fixture' asFileReference.
	self assert: (params at: 'rootUri') equals: 'file:///tmp/smallchat-init-fixture'.
	self assert: (params at: 'processId') isNil.
	caps := params at: 'capabilities'.
	docSym := ((caps at: 'textDocument') at: 'documentSymbol').
	self assert: (docSym at: 'hierarchicalDocumentSymbolSupport') equals: true
]
