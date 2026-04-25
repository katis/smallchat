Class {
	#name : 'SmallChatTSNodeWalkerTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-TreeSitter-Tests',
	#package : 'SmallChat-TreeSitter-Tests'
}

{ #category : 'availability' }
SmallChatTSNodeWalkerTest class >> isAvailable [
	^ self new isAvailable
]

{ #category : 'helpers' }
SmallChatTSNodeWalkerTest >> fixtureContents: aRelative [
	^ (self fixturePath: aRelative) asFileReference contents
]

{ #category : 'helpers' }
SmallChatTSNodeWalkerTest >> fixturePath: aRelative [
	"lib/fixtures/<aRelative> -- absolute. Tests live with the repo so this
	 path is stable; the fixture loader is local to walker tests."
	^ '/Users/katis/code/smallchat/lib/fixtures/' , aRelative
]

{ #category : 'availability' }
SmallChatTSNodeWalkerTest >> isAvailable [
	(Smalltalk globals includesKey: #TSLanguage) ifFalse: [ ^ false ].
	^ [ FFIMacLibraryFinder findAnyLibrary: #( 'libtree-sitter-tsx.dylib' ).
	    FFIMacLibraryFinder findAnyLibrary: #( 'libtree-sitter-css.dylib' ).
	    true ]
		on: Error
		do: [ :_ | false ]
]

{ #category : 'tests' }
SmallChatTSNodeWalkerTest >> testClassSelectorsOnButtonModuleCssReturnsThree [
	"Button.module.css has three class selectors: .primary .secondary .disabled."
	| source tree selectors |
	self isAvailable ifFalse: [ ^ self skip ].
	source := self fixtureContents: 'ts-css-small/Button.module.css'.
	tree := SmallChatTSParser new parseCssString: source.
	selectors := SmallChatTSNodeWalker new classSelectors: tree rootNode.
	self assert: selectors size equals: 3
]

{ #category : 'tests - imports' }
SmallChatTSNodeWalkerTest >> testImportSpecifiersIncludeSpecifierByteRange [
  "importSpecifiersIn:source: returns the import_statement byte range
   (startByte / endByte) AND the specifier string contents byte range
   (specifierStartByte / specifierEndByte). The specifier range covers
   only the contents between the quotes, which is what tsgo expects as
   the position for textDocument/definition."
  | parser walker tree spec text |
  parser := SmallChatTSParser new.
  walker := SmallChatTSNodeWalker new.
  text := 'import React from "react";'.
  tree := parser parseTsxString: text.
  spec := (walker importSpecifiersIn: tree rootNode source: text) first.
  self assert: (spec at: 'specifier') equals: 'react'.
  self assert: (spec at: 'startByte') equals: 0.
  self assert: (spec at: 'endByte') equals: text size.
  "the contents between the quotes is bytes 19..24"
  self assert: (spec at: 'specifierStartByte') equals: 19.
  self assert: (spec at: 'specifierEndByte') equals: 24
]

{ #category : 'tests' }
SmallChatTSNodeWalkerTest >> testImportStatementsOnButtonTsxReturnsOneImport [
	| source tree imports |
	self isAvailable ifFalse: [ ^ self skip ].
	source := self fixtureContents: 'ts-small/Button.tsx'.
	tree := SmallChatTSParser new parseTsxString: source.
	imports := SmallChatTSNodeWalker new importStatements: tree rootNode.
	self assert: imports size equals: 1.
	self assert: imports first type equals: 'import_statement'
]

{ #category : 'tests' }
SmallChatTSNodeWalkerTest >> testJsxAttributeValuesOnButtonTsxReturnsThree [
	"ts-small/Button.tsx jsx_attribute count: 3 (type, className, onClick).
	 Walker returns the value child of each jsx_attribute."
	| source tree values |
	self isAvailable ifFalse: [ ^ self skip ].
	source := self fixtureContents: 'ts-small/Button.tsx'.
	tree := SmallChatTSParser new parseTsxString: source.
	values := SmallChatTSNodeWalker new jsxAttributeValues: tree rootNode.
	self assert: values size equals: 3
]

{ #category : 'tests' }
SmallChatTSNodeWalkerTest >> testMemberExpressionsForStylesOnCssBridgeTsxReturnsTwo [
	"ts-css-small/Button.tsx has 4 member_expression nodes total:
	 props.variant, styles.primary, styles.secondary, props.label.
	 Filter on objectName = 'styles' returns 2."
	| source tree members |
	self isAvailable ifFalse: [ ^ self skip ].
	source := self fixtureContents: 'ts-css-small/Button.tsx'.
	tree := SmallChatTSParser new parseTsxString: source.
	members := SmallChatTSNodeWalker new
		memberExpressionsFor: tree rootNode
		objectName: 'styles'
		inSource: source.
	self assert: members size equals: 2
]

{ #category : 'tests' }
SmallChatTSNodeWalkerTest >> testTopLevelDeclarationsOnButtonTsxReturnsTwoDeclarations [
	"ts-small/Button.tsx top-level: import_statement, type_alias_declaration,
	 export_statement. Walker excludes imports -- 2 declarations."
	| source tree decls types |
	self isAvailable ifFalse: [ ^ self skip ].
	source := self fixtureContents: 'ts-small/Button.tsx'.
	tree := SmallChatTSParser new parseTsxString: source.
	decls := SmallChatTSNodeWalker new topLevelDeclarations: tree rootNode.
	types := decls collect: [ :n | n type ].
	self assert: decls size equals: 2.
	self assert: (types includes: 'type_alias_declaration').
	self assert: (types includes: 'export_statement')
]
