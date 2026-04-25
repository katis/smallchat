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

{ #category : 'tests' }
SmallChatCssRenameClassTest >> testRenameCssClassUpdatesTsConsumerAtomically [
  "Rename .btn -> .buttonPrimary across a CSS module file and one TS file
   that imports it. Both files are rewritten in a single applier call;
   rollback restores both."
  | fs cssFile tsFile cssUri tsUri cssOriginal tsOriginal cssExpected tsExpected
    famixModel cssFileEntity cssClass importEntity ref tsBytePos
    applier cmd outcome |
  fs := FileSystem memory.
  cssOriginal := '.btn { color: red }'.
  cssExpected := '.buttonPrimary { color: red }'.
  tsOriginal := 'import styles from "./Button.module.css";' , String lf , 'const x = styles.btn;'.
  tsExpected := 'import styles from "./Button.module.css";' , String lf , 'const x = styles.buttonPrimary;'.
  cssFile := fs / '/Button.module.css'.
  cssFile writeStreamDo: [ :s | s nextPutAll: cssOriginal ].
  tsFile := fs / '/Button.tsx'.
  tsFile writeStreamDo: [ :s | s nextPutAll: tsOriginal ].
  cssUri := 'file://' , cssFile fullName.
  tsUri := 'file://' , tsFile fullName.
  famixModel := SmallChatFamixModel new.
  cssFileEntity := famixModel newCSSModuleFile.
  cssFileEntity name: 'Button.module.css'.
  cssFileEntity sourceAnchor: (SmallChatFamixSourceAnchor fileUri: cssUri startByte: 0 endByte: cssOriginal size).
  cssClass := famixModel newCSSClass.
  cssClass name: 'btn'; file: cssFileEntity.
  cssClass sourceAnchor: (SmallChatFamixSourceAnchor fileUri: cssUri startByte: 0 endByte: 4).
  importEntity := famixModel newImport.
  importEntity name: './Button.module.css'.
  importEntity resolvedUri: cssUri.
  importEntity sourceAnchor: (SmallChatFamixSourceAnchor fileUri: tsUri startByte: 0 endByte: 41).
  ref := famixModel newCSSClassReference.
  tsBytePos := (tsOriginal indexOfSubCollection: 'styles.btn') - 1.
  ref name: 'btn'; referent: cssClass.
  ref sourceAnchor: (SmallChatFamixSourceAnchor
    fileUri: tsUri
    startByte: tsBytePos
    endByte: tsBytePos + 'styles.btn' size).
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  cmd := SmallChatCssRenameClassCommand new
    applier: applier;
    cssFileUri: cssUri;
    oldClassName: 'btn';
    newClassName: 'buttonPrimary';
    model: famixModel;
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: (cssFile readStreamDo: [ :s | s upToEnd ]) equals: cssExpected.
  self assert: (tsFile readStreamDo: [ :s | s upToEnd ]) equals: tsExpected.
  cmd rollback: outcome rollbackToken.
  self assert: (cssFile readStreamDo: [ :s | s upToEnd ]) equals: cssOriginal.
  self assert: (tsFile readStreamDo: [ :s | s upToEnd ]) equals: tsOriginal
]
