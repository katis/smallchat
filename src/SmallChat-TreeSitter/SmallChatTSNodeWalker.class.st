Class {
	#name : 'SmallChatTSNodeWalker',
	#superclass : 'Object',
	#category : 'SmallChat-TreeSitter',
	#package : 'SmallChat-TreeSitter'
}

{ #category : 'walking' }
SmallChatTSNodeWalker >> importStatements: aRootNode [
	"Return all import_statement nodes in the program. Imports live at
	 the top level in TS / TSX, so a top-level scan suffices."
	^ aRootNode namedChildren select: [ :n | n type = 'import_statement' ]
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
