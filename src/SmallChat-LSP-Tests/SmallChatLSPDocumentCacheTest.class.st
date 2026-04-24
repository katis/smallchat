Class {
	#name : 'SmallChatLSPDocumentCacheTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-LSP-Tests',
	#package : 'SmallChat-LSP-Tests'
}

{ #category : 'tests - cache' }
SmallChatLSPDocumentCacheTest >> testChangeUriIncrementsVersionAndReplacesText [
	"changeUri:text: on an open URI bumps its version and replaces the text."
	| cache uri |
	cache := SmallChatLSPDocumentCache new.
	uri := 'file:///tmp/x.ts'.
	cache openUri: uri languageId: 'typescript' text: 'v1'.
	cache changeUri: uri text: 'v2'.
	self assert: (cache versionOf: uri) equals: 2.
	self assert: (cache textOf: uri) equals: 'v2'.
	cache changeUri: uri text: 'v3'.
	self assert: (cache versionOf: uri) equals: 3.
	self assert: (cache textOf: uri) equals: 'v3'
]

{ #category : 'tests - cache' }
SmallChatLSPDocumentCacheTest >> testCloseUriRemovesEntry [
	"closeUri: drops the URI from the cache; querying it afterwards should
	 behave the same as a URI that was never opened."
	| cache uri |
	cache := SmallChatLSPDocumentCache new.
	uri := 'file:///tmp/x.ts'.
	cache openUri: uri languageId: 'typescript' text: 'hi'.
	cache closeUri: uri.
	self assert: (cache isOpen: uri) equals: false
]

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
