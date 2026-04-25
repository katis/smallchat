Class {
	#name : 'SmallChatWorkspaceEditApplier',
	#superclass : 'Object',
	#category : 'SmallChat-Refactoring',
	#package : 'SmallChat-Refactoring'
}

{ #category : 'execution' }
SmallChatWorkspaceEditApplier >> applyTextEdit: anEditDict to: aString [
  "Replace the byte-range described by anEditDict's range with its newText."
  | range startByte endByte newText utf8 prefix suffix |
  range := SmallChatTSRange fromLSPPositionRange: (anEditDict at: 'range') source: aString.
  startByte := range startByte.
  endByte := range endByte.
  newText := anEditDict at: 'newText'.
  utf8 := aString utf8Encoded.
  prefix := utf8 copyFrom: 1 to: startByte.
  suffix := utf8 copyFrom: endByte + 1 to: utf8 size.
  ^ (prefix , newText utf8Encoded , suffix) utf8Decoded
]

{ #category : 'execution' }
SmallChatWorkspaceEditApplier >> applyTextEdits: anArray to: aString [
  "Apply LSP TextEdit dictionaries to aString in reverse order of start byte
   so prefix offsets remain stable. Each edit's range is converted from LSP
   UTF-16 position to UTF-8 byte offsets via SmallChatTSRange."
  | sorted current |
  sorted := anArray asSortedCollection: [ :a :b |
    (self editStartByte: a inSource: aString) > (self editStartByte: b inSource: aString) ].
  current := aString.
  sorted do: [ :edit | current := self applyTextEdit: edit to: current ].
  ^ current
]

{ #category : 'execution' }
SmallChatWorkspaceEditApplier >> applyWorkspaceEdit: aWorkspaceEdit withSources: aSources [
  "Apply a WorkspaceEdit changes-form against aSources (uri -> string) and return
   a SmallChatApplyResult carrying the rewritten sources. URIs not mentioned in
   the edit pass through unchanged. Edits within one URI are applied reverse-
   sorted by range start so earlier byte offsets stay stable."
  | newSources changes |
  newSources := Dictionary new.
  aSources keysAndValuesDo: [ :uri :text | newSources at: uri put: text ].
  changes := aWorkspaceEdit at: 'changes' ifAbsent: [ Dictionary new ].
  changes keysAndValuesDo: [ :uri :edits |
    | text |
    text := aSources at: uri.
    newSources at: uri put: (self applyTextEdits: edits to: text) ].
  ^ SmallChatApplyResult successWithSources: newSources
]

{ #category : 'execution' }
SmallChatWorkspaceEditApplier >> editStartByte: anEditDict inSource: aString [
  ^ (SmallChatTSRange fromLSPPositionRange: (anEditDict at: 'range') source: aString) startByte
]
