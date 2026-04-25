Class {
	#name : 'SmallChatWorkspaceEditApplierTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'tests' }
SmallChatWorkspaceEditApplierTest >> testEditAcrossBmpNonAsciiUsesUtf16PositionsCorrectly [
  "BMP non-ASCII (here: GREEK SMALL LETTER PI, U+03C0 -- 1 UTF-16 code unit,
   2 UTF-8 bytes) sits between the prefix and the edit range. The applier
   must convert LSP UTF-16 characters to UTF-8 byte offsets so the slice
   does not split the multi-byte sequence."
  | applier pi source edit sources expected result |
  pi := (Character codePoint: 16r03C0) asString.
  source := 'Hello, ' , pi , ' World!'. "15 chars, 16 utf-8 bytes; 'World' at char 9..14"
  expected := 'Hello, ' , pi , ' Earth!'.
  applier := SmallChatWorkspaceEditApplier new.
  edit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: 'file:///t/a.txt' put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 9; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 14; yourself);
          yourself);
        at: 'newText' put: 'Earth';
        yourself));
      yourself);
    yourself.
  sources := Dictionary new at: 'file:///t/a.txt' put: source; yourself.
  result := applier applyWorkspaceEdit: edit withSources: sources.
  self assert: result isSuccess.
  self assert: (result newSourceFor: 'file:///t/a.txt') equals: expected
]

{ #category : 'tests' }
SmallChatWorkspaceEditApplierTest >> testEmptyChangesLeaveSourceUnchanged [
  | applier edit sources result |
  applier := SmallChatWorkspaceEditApplier new.
  edit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: 'file:///t/a.txt' put: #();
      yourself);
    yourself.
  sources := Dictionary new at: 'file:///t/a.txt' put: 'hello'; yourself.
  result := applier applyWorkspaceEdit: edit withSources: sources.
  self assert: result isSuccess.
  self assert: (result newSourceFor: 'file:///t/a.txt') equals: 'hello'
]

{ #category : 'tests' }
SmallChatWorkspaceEditApplierTest >> testMultipleEditsAppliedInReverseOrder [
  "Two non-overlapping edits at line 0 cols 7-12 and 14-19 in
   'Hello, World, Earth!' rewrite to 'Hello, there, friend!'. The applier
   must process the later edit first so the earlier edit's byte offsets
   remain valid; an in-order naive walk would shift the second range."
  | applier edit sources result |
  applier := SmallChatWorkspaceEditApplier new.
  edit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: 'file:///t/a.txt' put: (Array
        with: (Dictionary new
          at: 'range' put: (Dictionary new
            at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 7; yourself);
            at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 12; yourself);
            yourself);
          at: 'newText' put: 'there';
          yourself)
        with: (Dictionary new
          at: 'range' put: (Dictionary new
            at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 14; yourself);
            at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 19; yourself);
            yourself);
          at: 'newText' put: 'friend';
          yourself));
      yourself);
    yourself.
  sources := Dictionary new at: 'file:///t/a.txt' put: 'Hello, World, Earth!'; yourself.
  result := applier applyWorkspaceEdit: edit withSources: sources.
  self assert: result isSuccess.
  self assert: (result newSourceFor: 'file:///t/a.txt') equals: 'Hello, there, friend!'
]

{ #category : 'tests' }
SmallChatWorkspaceEditApplierTest >> testOverlappingEditsAreReportedAsError [
  "Two edits whose byte ranges overlap within one document violate the
   LSP spec's undefined-behaviour clause. The applier must reject them:
   isSuccess returns false, and source bytes are not mutated."
  | applier edit sources result |
  applier := SmallChatWorkspaceEditApplier new.
  edit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: 'file:///t/a.txt' put: (Array
        with: (Dictionary new
          at: 'range' put: (Dictionary new
            at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 7; yourself);
            at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 12; yourself);
            yourself);
          at: 'newText' put: 'X';
          yourself)
        with: (Dictionary new
          at: 'range' put: (Dictionary new
            at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 10; yourself);
            at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 14; yourself);
            yourself);
          at: 'newText' put: 'Y';
          yourself));
      yourself);
    yourself.
  sources := Dictionary new at: 'file:///t/a.txt' put: 'Hello, World!'; yourself.
  result := applier applyWorkspaceEdit: edit withSources: sources.
  self deny: result isSuccess.
  self assert: result errorReason notNil
]

{ #category : 'tests' }
SmallChatWorkspaceEditApplierTest >> testSingleTextEditReplacesRange [
  | applier edit sources result |
  applier := SmallChatWorkspaceEditApplier new.
  edit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: 'file:///t/a.txt' put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 7; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 12; yourself);
          yourself);
        at: 'newText' put: 'there';
        yourself));
      yourself);
    yourself.
  sources := Dictionary new at: 'file:///t/a.txt' put: 'Hello, World!'; yourself.
  result := applier applyWorkspaceEdit: edit withSources: sources.
  self assert: result isSuccess.
  self assert: (result newSourceFor: 'file:///t/a.txt') equals: 'Hello, there!'
]
