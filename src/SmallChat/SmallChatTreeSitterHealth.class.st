Class {
	#name : 'SmallChatTreeSitterHealth',
	#superclass : 'Object',
	#category : 'SmallChat',
	#package : 'SmallChat'
}

{ #category : 'checking' }
SmallChatTreeSitterHealth class >> check [
    "Probe the full expectedDylibs list and return the report."
    ^ self checkDylibs: self expectedDylibs
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
     #check / #checkDylibs:) to aStream. Returns the same result
     so callers can pipe."
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
    aStream cr.
    ^ aResult
]

{ #category : 'checking' }
SmallChatTreeSitterHealth class >> reportOn: aStream [
    "Run a full check and write a human-readable summary to aStream."
    ^ self reportCheck: self check on: aStream
]
