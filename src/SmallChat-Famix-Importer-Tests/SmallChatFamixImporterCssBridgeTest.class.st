Class {
	#name : 'SmallChatFamixImporterCssBridgeTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

{ #category : 'helpers' }
SmallChatFamixImporterCssBridgeTest >> newImporterOn: aModel [
  ^ SmallChatFamixImporter new
    model: aModel
    client: nil
    parser: SmallChatTSParser new
    walker: SmallChatTSNodeWalker new
]

{ #category : 'helpers' }
SmallChatFamixImporterCssBridgeTest >> preimportCssFileUri: aCssUri text: aText into: aModel via: anImporter [
  "Run the CSS importer for aText so the model has CSSModuleFile + CSSClass
   entities to link against."
  anImporter importCssFileUri: aCssUri text: aText
]

{ #category : 'helpers' }
SmallChatFamixImporterCssBridgeTest >> preimportTsImportUri: aTsUri specifier: aSpecifier resolvedTo: aResolvedUri into: aModel [
  "Pre-populate a SmallChatFamixImport as if S2 had already resolved it.
   Anchor fileUri ties the import to the TS file; resolvedUri points at
   the CSS file so the bridge can find the CSSModuleFile by URI."
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

{ #category : 'tests' }
SmallChatFamixImporterCssBridgeTest >> testStylesAccessResolvesToCssClass [
  "Given a TS file that imports styles from a .module.css and accesses
   styles.primary, the bridge emits one SmallChatFamixCSSClassReference
   whose referent is the matching SmallChatFamixCSSClass and whose
   unresolved flag is falsy."
  | model importer cssUri tsUri tsText cssText refs ref primary |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  cssUri := 'file:///t/Button.module.css'.
  tsUri := 'file:///t/Button.tsx'.
  cssText := '.primary { color: red }
.secondary { color: blue }'.
  tsText := 'import styles from "./Button.module.css";
const x = styles.primary;'.
  self preimportCssFileUri: cssUri text: cssText into: model via: importer.
  self
    preimportTsImportUri: tsUri
    specifier: './Button.module.css'
    resolvedTo: cssUri
    into: model.
  importer linkCssReferencesInTsUri: tsUri text: tsText.
  refs := model allWithType: SmallChatFamixCSSClassReference.
  self assert: refs size equals: 1.
  ref := refs first.
  primary := (model allWithType: SmallChatFamixCSSClass) detect: [ :c | c name = 'primary' ].
  self assert: ref referent identicalTo: primary.
  self deny: ref unresolved
]
