Class {
	#name : 'SmallChatTSGrammar',
	#superclass : 'Object',
	#instVars : [
		'libraryClass',
		'entryPointSelector'
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
  "Cached singleton wrapping the CSS grammar."
  ^ CssInstance ifNil: [
    CssInstance := self new
      libraryClass: TSCSSLibrary entryPointSelector: #tree_sitter_css ]
]

{ #category : 'accessing' }
SmallChatTSGrammar class >> reset [
	"Drop the cached singletons. Used by tests; not for production paths."
	TsxInstance := nil.
	CssInstance := nil
]

{ #category : 'accessing' }
SmallChatTSGrammar class >> tsx [
  "Cached singleton wrapping the TSX grammar. The wrapper is cached as a
   class-side singleton (cheap, stable identity), but the underlying TSLanguage
   handle is re-fetched on every `language` access -- caching FFI handles
   across image save/restart leaves NULL pointers."
  ^ TsxInstance ifNil: [
    TsxInstance := self new
      libraryClass: TSTsxLibrary entryPointSelector: #tree_sitter_tsx ]
]

{ #category : 'accessing' }
SmallChatTSGrammar >> language [
  "Always re-fetch the language pointer from the live dylib. Caching the
   handle persists across image save/restart, where Pharo nils FFI handles
   and leaves a NULL pointer behind that segfaults at parse time. The C
   entry-point returns a static dylib address, so each call is cheap."
  ^ libraryClass uniqueInstance perform: entryPointSelector
]

{ #category : 'initialization' }
SmallChatTSGrammar >> libraryClass: aClass entryPointSelector: aSymbol [
  "Initialize with the FFI library class and the entry-point selector that
   returns a fresh TSLanguage from the dylib. Stored as data, not as a
   resolved handle, so `language` always re-fetches from the live dylib."
  libraryClass := aClass.
  entryPointSelector := aSymbol
]
