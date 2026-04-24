Class {
	#name : 'SmallChatLSPDocumentCache',
	#superclass : 'Object',
	#instVars : [
		'entries'
	],
	#category : 'SmallChat-LSP',
	#package : 'SmallChat-LSP'
}

{ #category : 'lifecycle' }
SmallChatLSPDocumentCache >> changeUri: aUri text: aString [
	"Bump the version and replace the text for aUri. Whole-document sync --
	 incremental-range sync may arrive later when tsgo coverage justifies it."
	| entry |
	entry := entries at: aUri.
	entry at: 'version' put: (entry at: 'version') + 1.
	entry at: 'text' put: aString.
	^ self
]

{ #category : 'initialization' }
SmallChatLSPDocumentCache >> initialize [
	super initialize.
	entries := Dictionary new
]

{ #category : 'accessing' }
SmallChatLSPDocumentCache >> languageIdOf: aUri [
	^ (entries at: aUri) at: 'languageId'
]

{ #category : 'lifecycle' }
SmallChatLSPDocumentCache >> openUri: aUri languageId: aLanguageId text: aString [
	"Register aUri in the cache at version 1 with the given languageId/text.
	 Overwrites any prior entry -- LSP didOpen on an already-open URI is a
	 protocol error; enforcement can be added when the need surfaces."
	entries at: aUri put: (Dictionary new
		at: 'languageId' put: aLanguageId;
		at: 'version' put: 1;
		at: 'text' put: aString;
		yourself).
	^ self
]

{ #category : 'accessing' }
SmallChatLSPDocumentCache >> textOf: aUri [
	^ (entries at: aUri) at: 'text'
]

{ #category : 'accessing' }
SmallChatLSPDocumentCache >> versionOf: aUri [
	^ (entries at: aUri) at: 'version'
]
