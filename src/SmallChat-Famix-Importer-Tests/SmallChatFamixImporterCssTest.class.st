Class {
	#name : 'SmallChatFamixImporterCssTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

{ #category : 'helpers' }
SmallChatFamixImporterCssTest >> newImporterOn: aModel [
  ^ SmallChatFamixImporter new
    model: aModel
    client: nil
    parser: SmallChatTSParser new
    walker: SmallChatTSNodeWalker new
]

{ #category : 'tests' }
SmallChatFamixImporterCssTest >> testDuplicateClassSelectorIsDedupedToOneCssClass [
  "The same class name appearing in multiple rule_sets (or with different
   pseudo-class qualifiers) emits exactly one SmallChatFamixCSSClass.
   Note: compound selectors like `.x.large` are NOT a duplicate of `.x` --
   they introduce both `x` and `large` as separate class identifiers."
  | model importer text |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := '.x { color: red }
.x:hover { color: blue }
.x:active { color: green }'.
  importer importCssFileUri: 'file:///t/Foo.module.css' text: text.
  self assert: (model allWithType: SmallChatFamixCSSClass) size equals: 1.
  self assert: (model allWithType: SmallChatFamixCSSClass) first name equals: 'x'
]

{ #category : 'tests' }
SmallChatFamixImporterCssTest >> testImportCssFileEmitsModuleFileAndOneCssClassPerSelector [
  "importCssFileUri:text: parses CSS via tree-sitter, emits one
   SmallChatFamixCSSModuleFile (named after the URI's last path segment,
   anchor over the whole text) and one SmallChatFamixCSSClass per unique
   class_selector. Each CSSClass carries a back-pointer to its file."
  | model importer text uri files file classes |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  uri := 'file:///t/Button.module.css'.
  text := '.primary { color: red }
.secondary { color: blue }
.disabled { opacity: 0.5 }'.
  importer importCssFileUri: uri text: text.
  files := model allWithType: SmallChatFamixCSSModuleFile.
  self assert: files size equals: 1.
  file := files first.
  self assert: file name equals: 'Button.module.css'.
  self assert: file sourceAnchor fileUri equals: uri.
  self assert: file sourceAnchor startByte equals: 0.
  self assert: file sourceAnchor endByte equals: text size.
  classes := model allWithType: SmallChatFamixCSSClass.
  self assert: classes size equals: 3.
  self assert: (classes collect: [ :c | c name ]) asSet equals: #('primary' 'secondary' 'disabled') asSet.
  self assert: (classes allSatisfy: [ :c | c file == file ])
]

{ #category : 'tests' }
SmallChatFamixImporterCssTest >> testNonModuleCssFileEmitsNothing [
  "A `.css` file that is not `.module.css` is skipped: no CSSModuleFile,
   no CSSClass. Plan 03: non-module CSS is out of scope for v1."
  | model importer |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  importer
    importCssFileUri: 'file:///t/global.css'
    text: '.btn { color: red }'.
  self assert: (model allWithType: SmallChatFamixCSSModuleFile) size equals: 0.
  self assert: (model allWithType: SmallChatFamixCSSClass) size equals: 0
]
