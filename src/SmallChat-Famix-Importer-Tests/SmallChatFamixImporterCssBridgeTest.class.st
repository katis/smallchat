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
SmallChatFamixImporterCssBridgeTest >> testMissingCssModuleFileTolerated [
  "If the corresponding CSSModuleFile is not yet in the model (CSS importer
   hasn't run for that URI yet), the bridge skips silently -- no exception,
   no partial references. Regeneration (S5) re-links once the CSS file lands."
  | model importer tsUri tsText |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  tsUri := 'file:///t/Foo.tsx'.
  tsText := 'import styles from "./Missing.module.css";
const x = styles.foo;'.
  self
    preimportTsImportUri: tsUri
    specifier: './Missing.module.css'
    resolvedTo: 'file:///t/Missing.module.css'
    into: model.
  importer linkCssReferencesInTsUri: tsUri text: tsText.
  self assert: (model allWithType: SmallChatFamixCSSClassReference) size equals: 0
]

{ #category : 'tests' }
SmallChatFamixImporterCssBridgeTest >> testNonModuleCssImportSkipped [
  "Imports of plain `.css` files (not `.module.css`) emit no CSSClassReference
   even if the TS file has matching member-expressions on the binding."
  | model importer tsUri tsText |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  tsUri := 'file:///t/Foo.tsx'.
  tsText := 'import sheet from "./global.css";
const x = sheet.foo;'.
  self
    preimportTsImportUri: tsUri
    specifier: './global.css'
    resolvedTo: 'file:///t/global.css'
    into: model.
  importer linkCssReferencesInTsUri: tsUri text: tsText.
  self assert: (model allWithType: SmallChatFamixCSSClassReference) size equals: 0
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

{ #category : 'tests' }
SmallChatFamixImporterCssBridgeTest >> testStylesAccessUnresolvedFlagsReference [
  "When the property name accessed in TS doesn't match any CSSClass on the
   imported CSSModuleFile (e.g. typo), emit a CSSClassReference with
   referent = nil and unresolved = true. The reference still records the
   site so the agent can surface it."
  | model importer cssUri tsUri tsText cssText refs ref |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  cssUri := 'file:///t/Button.module.css'.
  tsUri := 'file:///t/Bad.tsx'.
  cssText := '.primary { color: red }'.
  tsText := 'import styles from "./Button.module.css";
const x = styles.doesNotExist;'.
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
  self assert: ref name equals: 'doesNotExist'.
  self assert: ref referent equals: nil.
  self assert: ref unresolved
]
