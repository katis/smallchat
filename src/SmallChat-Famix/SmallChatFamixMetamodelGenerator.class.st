Class {
	#name : 'SmallChatFamixMetamodelGenerator',
	#superclass : 'FamixMetamodelGenerator',
	#instVars : [
		'project',
		'module'
	],
	#category : 'SmallChat-Famix',
	#package : 'SmallChat-Famix'
}

{ #category : 'accessing - meta' }
SmallChatFamixMetamodelGenerator class >> packageName [
	^ 'SmallChat-Famix'
]

{ #category : 'accessing - meta' }
SmallChatFamixMetamodelGenerator class >> prefix [
	"Pharo identifier prefix for generated classes. S4 spike: dashed
	 package names break FamixNG helper-class creation with
	 InvalidGlobalName, so we use the PascalCase form."
	^ 'SmallChatFamix'
]

{ #category : 'generation' }
SmallChatFamixMetamodelGenerator >> defineClasses [
	"FamixNG generator entry: declare each entity class in the metamodel.
	 The framework concatenates `prefix` with the supplied name to build
	 the final Pharo class name (e.g. #Project -> SmallChatFamixProject)."
	super defineClasses.
	project := builder newClassNamed: #Project.
	module := builder newClassNamed: #Module
]
