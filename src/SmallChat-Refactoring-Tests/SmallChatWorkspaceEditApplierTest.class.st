Class {
	#name : 'SmallChatWorkspaceEditApplierTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'helpers' }
SmallChatWorkspaceEditApplierTest >> helperEditFor: aUri start: aStart end: anEnd newText: aNewText [
  ^ Dictionary new
    at: 'changes' put: (Dictionary new
      at: aUri put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: aStart; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: anEnd; yourself);
          yourself);
        at: 'newText' put: aNewText;
        yourself));
      yourself);
    yourself
]

{ #category : 'helpers' }
SmallChatWorkspaceEditApplierTest >> helperFsAndUriFor: aPath text: aText [
  "Build a fresh in-memory FileSystem with aPath written from aText, return
   { fs. uri. fileRef. }."
  | fs file uri |
  fs := FileSystem memory.
  file := fs / aPath.
  file writeStreamDo: [ :s | s nextPutAll: aText ].
  uri := 'file://' , file fullName.
  ^ { fs. uri. file }
]

{ #category : 'tests' }
SmallChatWorkspaceEditApplierTest >> testApplyWorkspaceEditWritesNewBytesToDisk [
  "applyWorkspaceEdit: (no withSources:) reads the URI from disk through the
   injected FileSystem, applies the edit, and writes new bytes back. Tests
   read the file afterwards to confirm."
  | applier triple uri file edit result |
  triple := self helperFsAndUriFor: '/a.txt' text: 'Hello, World!'.
  uri := triple second.
  file := triple third.
  applier := SmallChatWorkspaceEditApplier new
    fileSystem: triple first;
    yourself.
  edit := self helperEditFor: uri start: 7 end: 12 newText: 'there'.
  result := applier applyWorkspaceEdit: edit.
  self assert: result isSuccess.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'Hello, there!'
]

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
SmallChatWorkspaceEditApplierTest >> testMultiFileEditFailureLeavesAllFilesUnchanged [
  "When one URI in a multi-file edit has overlapping edits the whole apply
   must fail without writing anything to disk. Both files keep their
   original bytes; no partial state is observable."
  | applier fs uri1 uri2 file1 file2 edit result |
  fs := FileSystem memory.
  file1 := fs / '/a.txt'.
  file2 := fs / '/b.txt'.
  file1 writeStreamDo: [ :s | s nextPutAll: 'alpha original' ].
  file2 writeStreamDo: [ :s | s nextPutAll: 'beta original' ].
  uri1 := 'file://' , file1 fullName.
  uri2 := 'file://' , file2 fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  edit := Dictionary new
    at: 'changes' put: (Dictionary new
      at: uri1 put: (Array with: (Dictionary new
        at: 'range' put: (Dictionary new
          at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 0; yourself);
          at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 5; yourself);
          yourself);
        at: 'newText' put: 'ALPHA';
        yourself));
      at: uri2 put: (Array
        with: (Dictionary new
          at: 'range' put: (Dictionary new
            at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 0; yourself);
            at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 4; yourself);
            yourself);
          at: 'newText' put: 'X';
          yourself)
        with: (Dictionary new
          at: 'range' put: (Dictionary new
            at: 'start' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 2; yourself);
            at: 'end' put: (Dictionary new at: 'line' put: 0; at: 'character' put: 6; yourself);
            yourself);
          at: 'newText' put: 'Y';
          yourself));
      yourself);
    yourself.
  result := applier applyWorkspaceEdit: edit.
  self deny: result isSuccess.
  self assert: (file1 readStreamDo: [ :s | s upToEnd ]) equals: 'alpha original'.
  self assert: (file2 readStreamDo: [ :s | s upToEnd ]) equals: 'beta original'
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
SmallChatWorkspaceEditApplierTest >> testRollbackRestoresFileToOriginalBytes [
  "applyWorkspaceEdit: must capture pre-edit bytes for every URI it writes
   so a follow-up rollback restores them. The rollback hook is on the
   applier itself, addressed by the token returned in the result."
  | applier triple uri file edit result token |
  triple := self helperFsAndUriFor: '/a.txt' text: 'Hello, World!'.
  uri := triple second.
  file := triple third.
  applier := SmallChatWorkspaceEditApplier new
    fileSystem: triple first;
    yourself.
  edit := self helperEditFor: uri start: 7 end: 12 newText: 'there'.
  result := applier applyWorkspaceEdit: edit.
  self assert: result isSuccess.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'Hello, there!'.
  token := result rollbackToken.
  self assert: token notNil.
  applier rollback: token.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: 'Hello, World!'
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
