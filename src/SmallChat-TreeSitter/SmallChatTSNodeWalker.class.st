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

{ #category : 'walking - private' }
SmallChatTSNodeWalker >> arrowReturnsJsx: anArrowFunctionNode [
  "True iff the arrow_function has a JSX body. Two shapes:
   concise body (last named child IS JSX) and block body (last named child
   is a statement_block with a return_statement carrying a JSX argument)."
  | jsxTypes body |
  jsxTypes := #('jsx_element' 'jsx_self_closing_element' 'jsx_fragment').
  body := anArrowFunctionNode namedChildren last.
  body ifNil: [ ^ false ].
  (jsxTypes includes: body type) ifTrue: [ ^ true ].
  body type = 'statement_block' ifFalse: [ ^ false ].
  ^ body namedChildren anySatisfy: [ :stmt |
      stmt type = 'return_statement'
        and: [ stmt namedChildren anySatisfy: [ :a | jsxTypes includes: a type ] ] ]
]

{ #category : 'walking' }
SmallChatTSNodeWalker >> classSelectors: aRootNode [
	"Return every class_selector node under aRootNode. CSS class
	 selectors live inside selectors lists, possibly nested under media
	 queries -- a recursive walk is the safe call."
	^ self allNodesOfType: 'class_selector' under: aRootNode
]

{ #category : 'walking - private' }
SmallChatTSNodeWalker >> functionBodyReturnsJsx: aFunctionDeclNode [
  "True iff the function's statement_block contains a return_statement whose
   argument is a JSX node (jsx_element, jsx_self_closing_element, or
   jsx_fragment). Conservative: only checks immediate children of the block."
  | block jsxTypes |
  block := aFunctionDeclNode namedChildren
    detect: [ :c | c type = 'statement_block' ]
    ifNone: [ ^ false ].
  jsxTypes := #('jsx_element' 'jsx_self_closing_element' 'jsx_fragment').
  ^ block namedChildren anySatisfy: [ :stmt |
      stmt type = 'return_statement'
        and: [ stmt namedChildren anySatisfy: [ :a | jsxTypes includes: a type ] ] ]
]

{ #category : 'walking' }
SmallChatTSNodeWalker >> importSpecifiersIn: aRootNode source: aSource [
  "Return an Array of (Dictionary at: 'specifier' put: String;
   at: 'startByte' put: Integer; at: 'endByte' put: Integer) for every
   top-level import_statement. The byte range covers the whole import_statement
   (`import ... from 'mod';`); the specifier is the source string contents
   (without quotes), extracted from the import_statement's `string` named
   child's `string_fragment` first child."
  | imports |
  imports := self importStatements: aRootNode.
  ^ imports collect: [ :imp | | sourceString fragment |
    sourceString := imp namedChildren detect: [ :c | c type = 'string' ].
    fragment := sourceString namedChildren first.
    Dictionary new
      at: 'specifier' put: (fragment textFromSourceText: aSource);
      at: 'startByte' put: imp startByte;
      at: 'endByte' put: imp endByte;
      yourself ]
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
SmallChatTSNodeWalker >> jsxComponentDeclarationsIn: aRootNode source: aSource [
  "Return Array of (Dictionary at: 'name' put: String;
   at: 'startByte' put: Integer; at: 'endByte' put: Integer;
   at: 'kind' put: Symbol). Three shapes: top-level
   function_declaration whose body returns JSX (#function); top-level
   const-arrow whose value is an arrow_function with a JSX body (#arrow);
   any nested pair (property_identifier + arrow_function with a JSX body),
   for TanStack-style `({ component: () => <X/> })` route declarations
   (#propertyArrow). #function / #arrow anchor on the top-level
   declaration; #propertyArrow anchors on the arrow_function itself,
   since the surrounding declaration may carry many unrelated pairs."
  | components |
  components := OrderedCollection new.
  aRootNode namedChildren do: [ :decl |
    decl type = 'function_declaration'
      ifTrue: [ (self functionBodyReturnsJsx: decl)
        ifTrue: [ | nameNode |
          nameNode := decl namedChildren detect: [ :c | c type = 'identifier' ].
          components add: (Dictionary new
            at: 'name' put: (nameNode textFromSourceText: aSource);
            at: 'startByte' put: decl startByte;
            at: 'endByte' put: decl endByte;
            at: 'kind' put: #function;
            yourself) ] ].
    (#('lexical_declaration' 'variable_declaration') includes: decl type)
      ifTrue: [
        (decl namedChildren select: [ :c | c type = 'variable_declarator' ]) do: [ :vd |
          | value |
          value := vd namedChildren last.
          (value notNil
            and: [ value type = 'arrow_function'
            and: [ self arrowReturnsJsx: value ] ])
              ifTrue: [ | nameNode |
                nameNode := vd namedChildren detect: [ :c | c type = 'identifier' ].
                components add: (Dictionary new
                  at: 'name' put: (nameNode textFromSourceText: aSource);
                  at: 'startByte' put: decl startByte;
                  at: 'endByte' put: decl endByte;
                  at: 'kind' put: #arrow;
                  yourself) ] ] ] ].
  (self allNodesOfType: 'pair' under: aRootNode) do: [ :pair |
    | key value |
    key := pair namedChildren first.
    value := pair namedChildren last.
    (key type = 'property_identifier'
      and: [ value type = 'arrow_function'
      and: [ self arrowReturnsJsx: value ] ])
        ifTrue: [
          components add: (Dictionary new
            at: 'name' put: (key textFromSourceText: aSource);
            at: 'startByte' put: value startByte;
            at: 'endByte' put: value endByte;
            at: 'kind' put: #propertyArrow;
            yourself) ] ].
  ^ components asArray
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
