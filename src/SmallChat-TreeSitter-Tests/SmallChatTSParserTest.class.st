Class {
	#name : 'SmallChatTSParserTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-TreeSitter-Tests',
	#package : 'SmallChat-TreeSitter-Tests'
}

{ #category : 'availability' }
SmallChatTSParserTest class >> isAvailable [
	^ self new isAvailable
]

{ #category : 'availability' }
SmallChatTSParserTest >> isAvailable [
	(Smalltalk globals includesKey: #TSLanguage) ifFalse: [ ^ false ].
	^ [ FFIMacLibraryFinder findAnyLibrary: #( 'libtree-sitter-tsx.dylib' ).
	    FFIMacLibraryFinder findAnyLibrary: #( 'libtree-sitter-css.dylib' ).
	    true ]
		on: Error
		do: [ :_ | false ]
]

{ #category : 'tests' }
SmallChatTSParserTest >> testParseCssStringReturnsTreeWithoutErrors [
	| tree errs |
	self isAvailable ifFalse: [ ^ self skip ].
	tree := SmallChatTSParser new parseCssString: '.primary { color: red; }'.
	errs := OrderedCollection new.
	tree rootNode namedChildren do: [ :n |
		n isErrorNode ifTrue: [ errs add: n type ] ].
	self assert: errs isEmpty.
	self assert: tree rootNode type equals: 'stylesheet'
]

{ #category : 'tests' }
SmallChatTSParserTest >> testParseTsxStringReturnsTreeWithoutErrors [
	| tree errs |
	self isAvailable ifFalse: [ ^ self skip ].
	tree := SmallChatTSParser new parseTsxString: 'const x: number = 1;'.
	errs := OrderedCollection new.
	tree rootNode namedChildren do: [ :n |
		n isErrorNode ifTrue: [ errs add: n type ] ].
	self assert: errs isEmpty.
	self assert: tree rootNode type equals: 'program'
]

{ #category : 'tests' }
SmallChatTSParserTest >> testRangeOfNodeReadsByteOffsetsFromTSNode [
	| tree firstChild range source |
	self isAvailable ifFalse: [ ^ self skip ].
	source := 'const x = 1;'.
	tree := SmallChatTSParser new parseTsxString: source.
	firstChild := tree rootNode namedChildren first.
	range := SmallChatTSParser new rangeOfNode: firstChild inSource: source.
	self assert: range startByte equals: firstChild startByte.
	self assert: range endByte equals: firstChild endByte.
	self assert: range source equals: source.
	self assert: range startLine equals: 0.
	self assert: range startCharacter equals: 0
]
