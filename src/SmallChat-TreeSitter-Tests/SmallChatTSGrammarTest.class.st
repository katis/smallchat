Class {
	#name : 'SmallChatTSGrammarTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-TreeSitter-Tests',
	#package : 'SmallChat-TreeSitter-Tests'
}

{ #category : 'availability' }
SmallChatTSGrammarTest class >> isAvailable [
	^ self new isAvailable
]

{ #category : 'availability' }
SmallChatTSGrammarTest >> isAvailable [
	(Smalltalk globals includesKey: #TSLanguage) ifFalse: [ ^ false ].
	^ [ FFIMacLibraryFinder findAnyLibrary: #( 'libtree-sitter-tsx.dylib' ).
	    FFIMacLibraryFinder findAnyLibrary: #( 'libtree-sitter-css.dylib' ).
	    true ]
		on: Error
		do: [ :_ | false ]
]

{ #category : 'tests' }
SmallChatTSGrammarTest >> testCssIsCachedSingleton [
	self isAvailable ifFalse: [ ^ self skip ].
	self assert: SmallChatTSGrammar css == SmallChatTSGrammar css
]

{ #category : 'tests' }
SmallChatTSGrammarTest >> testCssReturnsNonNilLanguagePointer [
	self isAvailable ifFalse: [ ^ self skip ].
	self assert: SmallChatTSGrammar css language isNil not
]

{ #category : 'tests' }
SmallChatTSGrammarTest >> testTsxIsCachedSingleton [
	self isAvailable ifFalse: [ ^ self skip ].
	self assert: SmallChatTSGrammar tsx == SmallChatTSGrammar tsx
]

{ #category : 'tests' }
SmallChatTSGrammarTest >> testTsxReturnsNonNilLanguagePointer [
	self isAvailable ifFalse: [ ^ self skip ].
	self assert: SmallChatTSGrammar tsx language isNil not
]
