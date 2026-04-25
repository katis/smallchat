"
This trait is used by Famix models.
It provides an API for creating entities and adding them to the model.


"
Trait {
	#name : 'SmallChatFamixTEntityCreator',
	#category : 'SmallChat-Famix-Model',
	#package : 'SmallChat-Famix',
	#tag : 'Model'
}

{ #category : 'meta' }
SmallChatFamixTEntityCreator classSide >> annotation [

	<FMClass: #TEntityCreator super: #Object>
	<package: #'SmallChat-Famix'>
	<generated>
	^ self
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newModule [

	<generated>
	^ self add: SmallChatFamixModule new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newProject [

	<generated>
	^ self add: SmallChatFamixProject new
]
