Class {
	#name : 'SmallChatLSPDocumentCacheTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'tests - cache' }
SmallChatLSPDocumentCacheTest >> testOpenUriRecordsVersionOneAndText [
	"openUri:languageId:text: registers a new URI at version 1 with the given
	 text and languageId."
	| cache uri |
	cache := SmallChatLSPDocumentCache new.
	uri := 'file:///tmp/x.ts'.
	cache openUri: uri languageId: 'typescript' text: 'let x = 1;'.
	self assert: (cache versionOf: uri) equals: 1.
	self assert: (cache textOf: uri) equals: 'let x = 1;'.
	self assert: (cache languageIdOf: uri) equals: 'typescript'
]
