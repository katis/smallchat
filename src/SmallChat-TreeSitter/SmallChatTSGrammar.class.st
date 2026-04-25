Class {
	#name : 'SmallChatTSGrammar',
	#superclass : 'Object',
	#instVars : [
		'language'
	],
	#classInstVars : [
		'TsxInstance',
		'CssInstance'
	],
	#category : 'SmallChat-TreeSitter',
	#package : 'SmallChat-TreeSitter'
}

{ #category : 'accessing' }
SmallChatTSGrammar class >> css [
	"Cached singleton wrapping the CSS language pointer."
	^ CssInstance ifNil: [
		CssInstance := self new
			language: TSCSSLibrary uniqueInstance tree_sitter_css;
			yourself ]
]

{ #category : 'accessing' }
SmallChatTSGrammar class >> reset [
	"Drop the cached singletons. Used by tests; not for production paths."
	TsxInstance := nil.
	CssInstance := nil
]

{ #category : 'accessing' }
SmallChatTSGrammar class >> tsx [
	"Cached singleton wrapping the TSX language pointer.
	Lazily initialised on first access; reused thereafter."
	^ TsxInstance ifNil: [
		TsxInstance := self new
			language: TSTsxLibrary uniqueInstance tree_sitter_tsx;
			yourself ]
]

{ #category : 'accessing' }
SmallChatTSGrammar >> language [
	^ language
]

{ #category : 'accessing' }
SmallChatTSGrammar >> language: aTSLanguage [
	language := aTSLanguage
]
