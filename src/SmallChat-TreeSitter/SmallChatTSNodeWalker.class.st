Class {
	#name : 'SmallChatTSNodeWalker',
	#superclass : 'Object',
	#category : 'SmallChat-TreeSitter',
	#package : 'SmallChat-TreeSitter'
}

{ #category : 'walking - private' }
SmallChatTSNodeWalker >> allNodesOfType: aTypeName under: aRootNode [
	"Recursive named-child walk -- returns every descendant whose type
	 matches. namedChildren do: only (S2 found namedChildAt: primitive-
	 fails on deep nodes)."
	| collected walk |
	collected := OrderedCollection new.
	walk := [ :node |
		node type = aTypeName ifTrue: [ collected add: node ].
		node namedChildren do: walk ].
	walk value: aRootNode.
	^ collected
]

{ #category : 'walking' }
SmallChatTSNodeWalker >> importStatements: aRootNode [
	"Return all import_statement nodes in the program. Imports live at
	 the top level in TS / TSX, so a top-level scan suffices."
	^ aRootNode namedChildren select: [ :n | n type = 'import_statement' ]
]

{ #category : 'walking' }
SmallChatTSNodeWalker >> jsxAttributeValues: aRootNode [
	"Return the value child of every jsx_attribute under aRootNode.
	 A jsx_attribute is shaped (property_identifier, value-node) -- the
	 value-node is the second named child when present (and the only
	 named child when the attribute is name-only like `disabled`)."
	| attrs |
	attrs := self allNodesOfType: 'jsx_attribute' under: aRootNode.
	^ attrs
		collect: [ :a | a namedChildren size > 1
			ifTrue: [ a namedChildren second ]
			ifFalse: [ a namedChildren first ] ]
]

{ #category : 'walking' }
SmallChatTSNodeWalker >> memberExpressionsFor: aRootNode objectName: aName inSource: aSource [
	"Variant that takes the source string explicitly. The walker is
	 stateless, so the caller supplies the source the tree was parsed from."
	| sourceText all |
	sourceText := aSource.
	all := self allNodesOfType: 'member_expression' under: aRootNode.
	^ all select: [ :m |
		(m namedChildren first textFromSourceText: sourceText) = aName ]
]

{ #category : 'walking' }
SmallChatTSNodeWalker >> topLevelDeclarations: aRootNode [
	"Return the program's named children whose type is a known
	 declaration kind. Imports are excluded; export_statement is
	 included as-is (its wrapped declaration is a single named child
	 the caller can unwrap if it cares)."
	| kinds |
	kinds := #(
		'function_declaration' 'class_declaration' 'interface_declaration'
		'type_alias_declaration' 'lexical_declaration' 'variable_declaration'
		'enum_declaration' 'export_statement').
	^ aRootNode namedChildren select: [ :n | kinds includes: n type ]
]
