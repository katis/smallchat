Class {
	#name : 'SmallChatCssRenameClassTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'tests' }
SmallChatCssRenameClassTest >> testRenameClassReplacesClassNameInSingleFile [
  "Walk class_selector nodes, replace each occurrence of the named
   identifier with newClassName via the applier. Other selectors are
   untouched. Rollback restores byte-for-byte."
  | fs file uri applier cmd outcome originalText expectedText |
  fs := FileSystem memory.
  file := fs / '/Button.module.css'.
  originalText := '.btn { color: red }
.other { background: blue }
.btn:hover { color: green }'.
  expectedText := '.button-primary { color: red }
.other { background: blue }
.button-primary:hover { color: green }'.
  file writeStreamDo: [ :s | s nextPutAll: originalText ].
  uri := 'file://' , file fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  cmd := SmallChatCssRenameClassCommand new
    applier: applier;
    cssFileUri: uri;
    oldClassName: 'btn';
    newClassName: 'button-primary';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: expectedText.
  cmd rollback: outcome rollbackToken.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: originalText
]
