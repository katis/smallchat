Class {
	#name : 'TSTsxLibrary',
	#superclass : 'FFILibrary',
	#category : 'SmallChat-TreeSitter',
	#package : 'SmallChat-TreeSitter'
}

{ #category : 'accessing - platform' }
TSTsxLibrary >> macLibraryName [
	"Find libtree-sitter-tsx in the VM Plugins dir; staged by install.sh
	from lib/tree-sitter/<platform>/. Mirrors TSTypescriptLibrary."
	^ FFIMacLibraryFinder findAnyLibrary: #( 'libtree-sitter-tsx.dylib' )
]

{ #category : 'accessing' }
TSTsxLibrary >> tree_sitter_tsx [
	"FFI entry point. Returns a TSLanguage pointer for the upstream TSX
	grammar (libtree-sitter-tsx). Mirrors TSTypescriptLibrary>>tree_sitter_typescript."
	^ self ffiCall: 'TSLanguage * tree_sitter_tsx ()'
]

{ #category : 'accessing - platform' }
TSTsxLibrary >> unix64LibraryName [
	^ FFIUnix64LibraryFinder findAnyLibrary: #( 'libtree-sitter-tsx.so' )
]

{ #category : 'accessing - platform' }
TSTsxLibrary >> win32LibraryName [
	^ FFIWindowsLibraryFinder findAnyLibrary: #( 'libtree-sitter-tsx.dll' )
]
