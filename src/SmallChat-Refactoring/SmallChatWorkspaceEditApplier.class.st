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
  "Apply a WorkspaceEdit changes-form against aSources (uri -> string).
   Returns SmallChatApplyResult with isSuccess=false and an errorReason
   when any URI's edits overlap; on success, returns the rewritten sources."
  | newSources changes |
  newSources := Dictionary new.
  aSources keysAndValuesDo: [ :uri :text | newSources at: uri put: text ].
  changes := aWorkspaceEdit at: 'changes' ifAbsent: [ Dictionary new ].
  changes keysAndValuesDo: [ :uri :edits |
    | text |
    text := aSources at: uri.
    (self overlapsAmong: edits inSource: text) ifTrue: [
      ^ SmallChatApplyResult errorReason:
        'Overlapping edits within ' , uri ].
    newSources at: uri put: (self applyTextEdits: edits to: text) ].
  ^ SmallChatApplyResult successWithSources: newSources
]

{ #category : 'execution' }
SmallChatWorkspaceEditApplier >> editStartByte: anEditDict inSource: aString [
  ^ (SmallChatTSRange fromLSPPositionRange: (anEditDict at: 'range') source: aString) startByte
]

{ #category : 'execution' }
SmallChatWorkspaceEditApplier >> overlapsAmong: anArray inSource: aString [
  "Return true when any two edits in anArray have overlapping byte ranges
   in aString. Touch (end == start) is allowed; strict overlap (any byte
   shared) is rejected."
  | ranges sorted |
  ranges := anArray collect: [ :edit |
    SmallChatTSRange fromLSPPositionRange: (edit at: 'range') source: aString ].
  sorted := ranges asSortedCollection: [ :a :b | a startByte < b startByte ].
  sorted asArray overlappingPairsDo: [ :a :b |
    a endByte > b startByte ifTrue: [ ^ true ] ].
  ^ false
]
