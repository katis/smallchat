Class {
	#name : 'SmallChatTSTsxLibraryTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-TreeSitter-Tests',
	#package : 'SmallChat-TreeSitter-Tests'
}

{ #category : 'availability' }
SmallChatTSTsxLibraryTest class >> isAvailable [
	^ self new isAvailable
]

{ #category : 'availability' }
SmallChatTSTsxLibraryTest >> isAvailable [
	"Skip when libtree-sitter-tsx is not staged in the VM Plugins dir."
	^ [ FFIMacLibraryFinder findAnyLibrary: #( 'libtree-sitter-tsx.dylib' ). true ]
		on: Error
		do: [ :_ | false ]
]

{ #category : 'tests' }
SmallChatTSTsxLibraryTest >> testTreeSitterTsxReturnsNonNilLanguage [
	self isAvailable ifFalse: [ ^ self skip ].
	self assert: TSTsxLibrary uniqueInstance tree_sitter_tsx isNil not
]
