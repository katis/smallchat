Class {
	#name : 'SmallChatWorkspaceEditApplier',
	#superclass : 'Object',
	#instVars : [
		'fileSystem'
	],
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
SmallChatWorkspaceEditApplier >> applyWorkspaceEdit: aWorkspaceEdit [
  "Read sources from disk, snapshot originals, run the in-memory transform,
   and on success write each new source back through the injected FileSystem.
   Rolls back already-written URIs if any write fails mid-batch and returns
   an error result. Successful applies attach the snapshot dictionary as
   rollbackToken on the result."
  | sources snapshot result writtenUris |
  sources := Dictionary new.
  snapshot := Dictionary new.
  (self urisFromWorkspaceEdit: aWorkspaceEdit) do: [ :uri | | original |
    original := self readSourceFor: uri.
    sources at: uri put: original.
    snapshot at: uri put: original ].
  result := self applyWorkspaceEdit: aWorkspaceEdit withSources: sources.
  result isSuccess ifFalse: [ ^ result ].
  writtenUris := OrderedCollection new.
  [
    sources keysDo: [ :uri |
      self writeSource: (result newSourceFor: uri) to: uri.
      writtenUris add: uri ]
  ] on: Error do: [ :e |
    writtenUris do: [ :uri |
      [ self writeSource: (snapshot at: uri) to: uri ]
        on: Error do: [ :_ | "best-effort restore" ] ].
    ^ SmallChatApplyResult errorReason: 'Write failed: ' , e messageText ].
  result rollbackToken: snapshot.
  ^ result
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

{ #category : 'private' }
SmallChatWorkspaceEditApplier >> fileFromUri: aUri [
  "Strip the file:// prefix and resolve against the injected FileSystem.
   We don't support non-file URIs (http, in-memory tsgo virtual modules) at
   this layer; the caller filtered to disk-resident files."
  | path |
  (aUri beginsWith: 'file://') ifFalse: [
    self error: 'Unsupported URI scheme for applier: ' , aUri ].
  path := aUri copyFrom: 'file://' size + 1 to: aUri size.
  ^ self fileSystem / path
]

{ #category : 'accessing' }
SmallChatWorkspaceEditApplier >> fileSystem [
  ^ fileSystem ifNil: [ fileSystem := FileSystem disk ]
]

{ #category : 'accessing' }
SmallChatWorkspaceEditApplier >> fileSystem: aFileSystem [
  fileSystem := aFileSystem
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

{ #category : 'private' }
SmallChatWorkspaceEditApplier >> readSourceFor: aUri [
  "Read aUri's file content through the injected FileSystem, returning a String."
  ^ (self fileFromUri: aUri) readStreamDo: [ :s | s upToEnd ]
]

{ #category : 'rollback' }
SmallChatWorkspaceEditApplier >> rollback: aToken [
  "Restore each URI in aToken (Dictionary uri -> original bytes) by writing
   the snapshot back through the same FileSystem the apply used."
  aToken keysAndValuesDo: [ :uri :original |
    self writeSource: original to: uri ]
]

{ #category : 'private' }
SmallChatWorkspaceEditApplier >> urisFromWorkspaceEdit: aWorkspaceEdit [
  "Return the set of URIs touched by aWorkspaceEdit. Currently supports the
   'changes' form only; 'documentChanges' lands when a refactoring needs it."
  ^ (aWorkspaceEdit at: 'changes' ifAbsent: [ Dictionary new ]) keys
]

{ #category : 'private' }
SmallChatWorkspaceEditApplier >> writeSource: aString to: aUri [
  "Overwrite the file at aUri with aString, going through the injected FileSystem."
  (self fileFromUri: aUri)
    writeStreamDo: [ :s | s nextPutAll: aString ]
]
