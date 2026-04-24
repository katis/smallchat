Class {
	#name : 'SmallChatTreeSitterHealthTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatTreeSitterHealthTest >> testCheckDylibsFindsPresentDylib [
    | result |
    result := SmallChatTreeSitterHealth checkDylibs: #( 'libtree-sitter.dylib' ).
    self assert: (result at: #missing) isEmpty.
    self assert: (result at: #found) size equals: 1
]

{ #category : 'tests' }
SmallChatTreeSitterHealthTest >> testCheckDylibsReportsMissingForBogusName [
    | result |
    result := SmallChatTreeSitterHealth checkDylibs: #( 'libtree-sitter-does-not-exist-xyz.dylib' ).
    self assert: (result at: #missing) size equals: 1.
    self assert: (result at: #missing) first equals: 'libtree-sitter-does-not-exist-xyz.dylib'.
    self assert: (result at: #found) isEmpty
]

{ #category : 'tests' }
SmallChatTreeSitterHealthTest >> testCheckSummedSizeMatchesExpectedDylibs [
    | result |
    result := SmallChatTreeSitterHealth check.
    self
        assert: (result at: #found) size + (result at: #missing) size
        equals: SmallChatTreeSitterHealth expectedDylibs size
]

{ #category : 'tests' }
SmallChatTreeSitterHealthTest >> testExpectedDylibsIncludesAllFive [
    self assert: SmallChatTreeSitterHealth expectedDylibs size equals: 5.
    self assert: (SmallChatTreeSitterHealth expectedDylibs includes: 'libtree-sitter.dylib').
    self assert: (SmallChatTreeSitterHealth expectedDylibs includes: 'libtree-sitter-typescript.dylib').
    self assert: (SmallChatTreeSitterHealth expectedDylibs includes: 'libtree-sitter-tsx.dylib').
    self assert: (SmallChatTreeSitterHealth expectedDylibs includes: 'libtree-sitter-css.dylib').
    self assert: (SmallChatTreeSitterHealth expectedDylibs includes: 'libtree-sitter-javascript.dylib')
]

{ #category : 'tests' }
SmallChatTreeSitterHealthTest >> testReportOnAllPresentWritesSummary [
    | stream result output |
    stream := WriteStream on: String new.
    result := SmallChatTreeSitterHealth reportOn: stream.
    output := stream contents.
    self assert: (output includesSubstring: 'found').
    self assert: (output includesSubstring: 'missing').
    self assert: (result at: #found) isCollection.
    self assert: (result at: #missing) isCollection
]

{ #category : 'tests' }
SmallChatTreeSitterHealthTest >> testReportOnMissingIncludesName [
    "Exercise the miss path by arranging for at least one miss via
     a monkey-wrench expectedDylibs override. Use a subclass-scope hack."
    | stream result |
    stream := WriteStream on: String new.
    result := SmallChatTreeSitterHealth
        reportCheck: (SmallChatTreeSitterHealth checkDylibs: #( 'libtree-sitter-absent-zz.dylib' 'libtree-sitter.dylib' ))
        on: stream.
    self assert: (stream contents includesSubstring: 'libtree-sitter-absent-zz.dylib').
    self assert: (result at: #missing) size equals: 1
]
