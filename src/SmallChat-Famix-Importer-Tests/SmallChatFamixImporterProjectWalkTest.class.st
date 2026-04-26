"
Tests for SmallChatFamixImporter>>importAllUnder:, the project-wide walk that drives lazy whole-project Famix population for an attached TS workspace. The walk respects a skip list (node_modules, .git, dist, build, .next) and dispatches by extension to the existing per-file importers.
"
Class {
	#name : 'SmallChatFamixImporterProjectWalkTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

{ #category : 'tests' }
SmallChatFamixImporterProjectWalkTest >> testImportAllUnderImportsCssAndSkipsNodeModules [
	"importAllUnder: walks the supplied root, dispatches each *.module.css to
	 importCssFileUri:text:, and skips node_modules. CSS-only fixture so the
	 LSP client is unused -- TS/JSX dispatch is exercised in a separate test
	 with a stubbed client."
	| fs root model importer cssClasses cssNames |
	fs := FileSystem memory.
	root := fs / 'project'.
	root ensureCreateDirectory.
	(root / 'styles.module.css') writeStreamDo: [ :s | s nextPutAll: '.kept { color: red; }' ].
	(root / 'nested') ensureCreateDirectory.
	(root / 'nested' / 'deep.module.css') writeStreamDo: [ :s | s nextPutAll: '.deep { }' ].
	(root / 'node_modules') ensureCreateDirectory.
	(root / 'node_modules' / 'ignored.module.css') writeStreamDo: [ :s | s nextPutAll: '.skip { }' ].
	model := SmallChatFamixModel new.
	importer := SmallChatFamixImporter new
		model: model
		client: nil
		parser: SmallChatTSParser new
		walker: SmallChatTSNodeWalker new.
	importer importAllUnder: root.
	cssClasses := model allWithType: SmallChatFamixCSSClass.
	cssNames := (cssClasses collect: [ :c | c name ]) asSortedCollection asArray.
	self assert: cssNames equals: #( 'deep' 'kept' )
]
