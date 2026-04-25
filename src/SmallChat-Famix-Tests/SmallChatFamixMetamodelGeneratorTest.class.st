Class {
	#name : 'SmallChatFamixMetamodelGeneratorTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Tests',
	#package : 'SmallChat-Famix-Tests'
}

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
