Class {
	#name : 'SmallChatFamixMetamodelGenerator',
	#superclass : 'FamixMetamodelGenerator',
	#instVars : [
		'project',
		'module',
		'class',
		'interface',
		'function',
		'method',
		'parameter',
		'field',
		'typeAlias'
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
	"Declare each entity class. The framework concatenates `prefix` with
	 the supplied name -- e.g. #Project -> SmallChatFamixProject."
	super defineClasses.
	project   := builder newClassNamed: #Project.
	module    := builder newClassNamed: #Module.
	class     := builder newClassNamed: #Class.
	interface := builder newClassNamed: #Interface.
	function  := builder newClassNamed: #Function.
	method    := builder newClassNamed: #Method.
	parameter := builder newClassNamed: #Parameter.
	field     := builder newClassNamed: #Field.
	typeAlias := builder newClassNamed: #TypeAlias
]
