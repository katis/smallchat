Class {
	#name : 'SmallChatFamixImporterRegenerationTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

{ #category : 'helpers' }
SmallChatFamixImporterRegenerationTest >> newImporterOn: aModel [
  ^ SmallChatFamixImporter new
    model: aModel
    client: nil
    parser: SmallChatTSParser new
    walker: SmallChatTSNodeWalker new
]

{ #category : 'helpers' }
SmallChatFamixImporterRegenerationTest >> preimportTsImportUri: aTsUri specifier: aSpecifier resolvedTo: aResolvedUri into: aModel [
  "Pre-populate a SmallChatFamixImport as if S2 had already resolved it.
   sourceAnchor.fileUri identifies the TS file; resolvedUri points at
   the CSS file so the bridge can find the CSSModuleFile."
  | imp |
  imp := aModel newImport.
  imp name: aSpecifier.
  imp sourceAnchor: (SmallChatFamixSourceAnchor
    fileUri: aTsUri
    startByte: 0
    endByte: 0).
  imp resolvedUri: aResolvedUri.
  imp classification: #srcLocal.
  ^ imp
]

{ #category : 'tests - drop' }
SmallChatFamixImporterRegenerationTest >> testDropEntitiesForUriRemovesAllAnchoredAtThatUri [
  "dropEntitiesForUri: removes every entity (Module, Class, Method, Field,
   Function, Interface, Import, JSXComponent, CSSModuleFile, CSSClass,
   CSSClassReference) whose sourceAnchor fileUri equals the dropped URI.
   Entities anchored at OTHER URIs are untouched. Project survives because
   the project itself has no sourceAnchor."
  | model importer cssA cssB |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  cssA := 'file:///t/A.module.css'.
  cssB := 'file:///t/B.module.css'.
  importer importCssFileUri: cssA text: '.x { } .y { }'.
  importer importCssFileUri: cssB text: '.z { }'.
  self assert: (model allWithType: SmallChatFamixCSSClass) size equals: 3.
  importer dropEntitiesForUri: cssA.
  self assert: (model allWithType: SmallChatFamixCSSModuleFile) size equals: 1.
  self assert: (model allWithType: SmallChatFamixCSSClass) size equals: 1.
  self assert: (model allWithType: SmallChatFamixCSSModuleFile) first sourceAnchor fileUri equals: cssB
]

{ #category : 'tests - reimport' }
SmallChatFamixImporterRegenerationTest >> testReimportDoesNotTouchOtherUris [
  "Re-importing one URI must not affect entities from other URIs."
  | model importer keepUri changeUri reimportArg |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  keepUri := 'file:///t/Keep.module.css'.
  changeUri := 'file:///t/Change.module.css'.
  importer importCssFileUri: keepUri text: '.kept { }'.
  importer importCssFileUri: changeUri text: '.old { }'.
  reimportArg := Dictionary new at: changeUri put: '.new { }'; yourself.
  importer reimportUris: reimportArg.
  self assert: ((model allWithType: SmallChatFamixCSSClass) collect: [ :c | c name ]) asSet
    equals: #('kept' 'new') asSet
]

{ #category : 'tests - reimport' }
SmallChatFamixImporterRegenerationTest >> testReimportEmptyDictIsNoop [
  "An empty reimport dict makes no model changes."
  | model importer cssUri before |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  cssUri := 'file:///t/X.module.css'.
  importer importCssFileUri: cssUri text: '.x { }'.
  before := (model allWithType: SmallChatFamixCSSClass) size.
  importer reimportUris: Dictionary new.
  self assert: (model allWithType: SmallChatFamixCSSClass) size equals: before
]

{ #category : 'tests - reimport' }
SmallChatFamixImporterRegenerationTest >> testReimportSingleCssFileReplacesItsEntities [
  "reimportUris: aDict drops entities anchored at each URI in aDict, then
   re-imports the URI's new text via the appropriate per-file path
   (.module.css -> CSS importer). Old CSSClass entities for that URI are
   gone; new ones reflect the updated source."
  | model importer cssUri text2 reimportArg classes |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  cssUri := 'file:///t/Foo.module.css'.
  importer importCssFileUri: cssUri text: '.A { } .B { }'.
  self assert: (model allWithType: SmallChatFamixCSSClass) size equals: 2.
  text2 := '.A { } .C { }'.
  reimportArg := Dictionary new at: cssUri put: text2; yourself.
  importer reimportUris: reimportArg.
  self assert: (model allWithType: SmallChatFamixCSSModuleFile) size equals: 1.
  classes := model allWithType: SmallChatFamixCSSClass.
  self assert: classes size equals: 2.
  self assert: (classes collect: [ :c | c name ]) asSet equals: #('A' 'C') asSet
]

{ #category : 'tests - reimport' }
SmallChatFamixImporterRegenerationTest >> testRelinkCssReferencesForUrisRefreshesAfterCssChange [
  "After a CSS module is re-imported (classes added / removed / renamed),
   relinkCssReferencesForUris: aDictTsUriToText drops stale CSSClassReference
   entities at each TS URI in the dict and re-runs the bridge against the
   current model state. References to renamed/removed classes flip to
   unresolved; surviving classes re-resolve to the new CSSClass entities."
  | model importer cssUri tsUri tsText cssText1 cssText2 refs newPrimary refX refY |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  cssUri := 'file:///t/Foo.module.css'.
  tsUri := 'file:///t/Foo.tsx'.
  cssText1 := '.x { color: red }
.y { color: blue }'.
  cssText2 := '.x { color: red }
.z { color: green }'.
  tsText := 'import styles from "./Foo.module.css";
const a = styles.x;
const b = styles.y;'.
  importer importCssFileUri: cssUri text: cssText1.
  self preimportTsImportUri: tsUri specifier: './Foo.module.css' resolvedTo: cssUri into: model.
  importer linkCssReferencesInTsUri: tsUri text: tsText.
  refs := model allWithType: SmallChatFamixCSSClassReference.
  self assert: refs size equals: 2.
  self assert: (refs allSatisfy: [ :r | r referent notNil ]).
  importer reimportUris: (Dictionary new at: cssUri put: cssText2; yourself).
  importer relinkCssReferencesForUris: (Dictionary new at: tsUri put: tsText; yourself).
  refs := model allWithType: SmallChatFamixCSSClassReference.
  self assert: refs size equals: 2.
  refX := refs detect: [ :r | r name = 'x' ].
  refY := refs detect: [ :r | r name = 'y' ].
  newPrimary := (model allWithType: SmallChatFamixCSSClass) detect: [ :c | c name = 'x' ].
  self assert: refX referent identicalTo: newPrimary.
  self deny: refX unresolved.
  self assert: refY referent equals: nil.
  self assert: refY unresolved
]
