Class {
	#name : 'SmallChatFamixMetamodelGenerator',
	#superclass : 'FamixMetamodelGenerator',
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
