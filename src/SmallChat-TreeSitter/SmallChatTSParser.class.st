Class {
	#name : 'SmallChatTSParser',
	#superclass : 'Object',
	#category : 'SmallChat-TreeSitter',
	#package : 'SmallChat-TreeSitter'
}

{ #category : 'parsing' }
SmallChatTSParser >> parseCssString: aString [
	"Parse aString with the CSS grammar and return a TSTree."
	| parser |
	parser := TSParser new.
	parser language: TSCSSLibrary uniqueInstance tree_sitter_css.
	^ parser parseString: aString
]

{ #category : 'parsing' }
SmallChatTSParser >> parseTsxString: aString [
	"Parse aString with the TSX grammar and return a TSTree.
	The TSX grammar is a strict superset of plain TS in practice (S6),
	so .ts content also routes through here."
	| parser |
	parser := TSParser new.
	parser language: TSTsxLibrary uniqueInstance tree_sitter_tsx.
	^ parser parseString: aString
]
