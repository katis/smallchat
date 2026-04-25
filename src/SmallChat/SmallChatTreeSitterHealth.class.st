Class {
	#name : 'SmallChatTreeSitterHealth',
	#superclass : 'Object',
	#category : 'SmallChat',
	#package : 'SmallChat'
}

{ #category : 'checking' }
SmallChatTreeSitterHealth class >> check [
	"Probe the full expectedDylibs list and the grammar singletons.
	 Returns a Dictionary with #found/#missing (dylib probe) and
	 #grammars (grammar probe -- see checkGrammars)."
	| dylibs |
	dylibs := self checkDylibs: self expectedDylibs.
	dylibs at: #grammars put: self checkGrammars.
	^ dylibs
]

{ #category : 'checking' }
SmallChatTreeSitterHealth class >> checkDylibs: aCollection [
    "Probe each dylib name with FFIMacLibraryFinder. Return a
     Dictionary with #found (OrderedCollection of name -> path
     associations) and #missing (OrderedCollection of names).
     A name lands in missing if the finder raises an Error."
    | found missing |
    found := OrderedCollection new.
    missing := OrderedCollection new.
    aCollection do: [ :name |
        [ | path |
          path := FFIMacLibraryFinder findAnyLibrary: (Array with: name).
          path
              ifNotNil: [ found add: name -> path ]
              ifNil: [ missing add: name ] ]
            on: Error
            do: [ :_ | missing add: name ] ].
    ^ Dictionary new
        at: #found put: found;
        at: #missing put: missing;
        yourself
]

{ #category : 'checking' }
SmallChatTreeSitterHealth class >> checkGrammars [
	"Probe the SmallChatTSGrammar singletons. Returns a Dictionary keyed
	 by grammar name with status: #ok if the singleton answers a non-nil
	 language pointer, #notLoaded if SmallChatTSGrammar isn't in the image
	 (verifier flavour), or the error message text on FFI / load failure.
	 Read SmallChatTSGrammar via Smalltalk globals at: ifAbsent: -- this
	 class lives in the SmallChat package; SmallChatTSGrammar is in the
	 SmallChat-TreeSitter package, which the verifier loads but whose
	 binding (TSLanguage etc.) the verifier does not."
	| grammarClass result |
	grammarClass := Smalltalk globals at: #SmallChatTSGrammar ifAbsent: [ nil ].
	grammarClass isNil ifTrue: [
		^ Dictionary new
			at: #tsx put: #notLoaded;
			at: #css put: #notLoaded;
			yourself ].
	result := Dictionary new.
	#(tsx css) do: [ :name |
		[ | g |
		  g := grammarClass perform: name.
		  result
			at: name
			put: (g language isNil ifTrue: [ #missing ] ifFalse: [ #ok ]) ]
		on: Error
		do: [ :e | result at: name put: e messageText ] ].
	^ result
]

{ #category : 'accessing' }
SmallChatTreeSitterHealth class >> expectedDylibs [
    "Names of the tree-sitter dylibs vendored under
     lib/tree-sitter/arm64-darwin/. install.sh copies these into the
     VM Plugins directory where FFIMacLibraryFinder discovers them."
    ^ #( 'libtree-sitter.dylib'
         'libtree-sitter-typescript.dylib'
         'libtree-sitter-tsx.dylib'
         'libtree-sitter-css.dylib'
         'libtree-sitter-javascript.dylib' )
]

{ #category : 'checking' }
SmallChatTreeSitterHealth class >> reportCheck: aResult on: aStream [
	"Write a human-readable summary of aResult (a Dictionary from
	 #check / #checkDylibs:) to aStream. Returns the same result so
	 callers can pipe."
	aStream
		<< 'SmallChat tree-sitter dylib check: ';
		<< (aResult at: #found) size printString;
		<< ' found, ';
		<< (aResult at: #missing) size printString;
		<< ' missing.'.
	(aResult at: #missing) isEmpty ifFalse: [
		aStream cr; << 'WARNING: the following dylibs could not be located via FFIMacLibraryFinder:'.
		(aResult at: #missing) do: [ :name |
			aStream cr; << '  - '; << name ].
		aStream cr; << 'Dev-image TreeSitter FFI calls will fail at first use. Run `just rebuild-mcp` to re-stage, or `just rebuild-dylibs` to rebuild from source.' ].
	(aResult at: #grammars ifAbsent: [ nil ]) ifNotNil: [ :grammars |
		aStream cr; << 'SmallChat tree-sitter grammar check:'.
		grammars keysAndValuesDo: [ :k :v |
			aStream cr; << '  - '; << k; << ': '; print: v ] ].
	aStream cr.
	^ aResult
]

{ #category : 'checking' }
SmallChatTreeSitterHealth class >> reportOn: aStream [
    "Run a full check and write a human-readable summary to aStream."
    ^ self reportCheck: self check on: aStream
]
