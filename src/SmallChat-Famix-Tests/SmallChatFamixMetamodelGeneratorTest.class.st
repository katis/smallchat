Class {
	#name : 'SmallChatFamixMetamodelGeneratorTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Tests',
	#package : 'SmallChat-Famix-Tests'
}

{ #category : 'tests' }
SmallChatFamixMetamodelGeneratorTest >> testEntitiesAcceptSourceAnchor [
	"sourceAnchor lives on the SmallChatFamixEntity root, so every
	 generated subclass inherits the slot + accessors."
	| anchor names |
	SmallChatFamixMetamodelGenerator new generate.
	anchor := SmallChatFamixSourceAnchor
		fileUri: 'file:///abs/x.tsx'
		startByte: 1 endByte: 2.
	names := #(SmallChatFamixModule SmallChatFamixClass SmallChatFamixFunction
		SmallChatFamixMethod SmallChatFamixField SmallChatFamixImport
		SmallChatFamixJSXComponent SmallChatFamixCSSModuleFile
		SmallChatFamixCSSClass SmallChatFamixCSSClassReference).
	names do: [ :n |
		| inst |
		inst := (Smalltalk globals at: n) new.
		inst sourceAnchor: anchor.
		self assert: inst sourceAnchor equals: anchor ]
]

{ #category : 'tests' }
SmallChatFamixMetamodelGeneratorTest >> testGenerateEmitsProjectAndModuleClasses [
	"After generate, the prefix-concatenated entity classes exist in the
	 image as proper Pharo classes."
	SmallChatFamixMetamodelGenerator new generate.
	self assert: (Smalltalk globals includesKey: #SmallChatFamixProject).
	self assert: (Smalltalk globals includesKey: #SmallChatFamixModule)
]

{ #category : 'tests' }
SmallChatFamixMetamodelGeneratorTest >> testPackageNameAndPrefix [
	"S4 warned: prefix must be a valid Pharo identifier; the dashed
	 package name fails helper-class creation. Use the PascalCase form."
	self assert: SmallChatFamixMetamodelGenerator packageName equals: 'SmallChat-Famix'.
	self assert: SmallChatFamixMetamodelGenerator prefix equals: 'SmallChatFamix'
]

{ #category : 'tests' }
SmallChatFamixMetamodelGeneratorTest >> testSliceACoreEntitiesPresentAfterGenerate [
	"Slice A: 7 core TS/JS entities concat-prefixed with the metamodel
	 prefix and rooted on SmallChatFamixEntity."
	| names |
	SmallChatFamixMetamodelGenerator new generate.
	names := #(SmallChatFamixClass SmallChatFamixInterface
		SmallChatFamixFunction SmallChatFamixMethod
		SmallChatFamixParameter SmallChatFamixField
		SmallChatFamixTypeAlias).
	names do: [ :n |
		self assert: (Smalltalk globals includesKey: n) description: n , ' missing' ]
]

{ #category : 'tests' }
SmallChatFamixMetamodelGeneratorTest >> testSliceBCrossCuttingEntitiesPresentAfterGenerate [
	"Slice B: 5 cross-cutting + CSS bridge entities."
	| names |
	SmallChatFamixMetamodelGenerator new generate.
	names := #(SmallChatFamixImport SmallChatFamixJSXComponent
		SmallChatFamixCSSModuleFile SmallChatFamixCSSClass
		SmallChatFamixCSSClassReference).
	names do: [ :n |
		self assert: (Smalltalk globals includesKey: n) description: n , ' missing' ]
]
