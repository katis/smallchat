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
SmallChatFamixTEntityCreator >> newCSSClass [

	<generated>
	^ self add: SmallChatFamixCSSClass new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newCSSClassReference [

	<generated>
	^ self add: SmallChatFamixCSSClassReference new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newCSSModuleFile [

	<generated>
	^ self add: SmallChatFamixCSSModuleFile new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newClass [

	<generated>
	^ self add: SmallChatFamixClass new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newField [

	<generated>
	^ self add: SmallChatFamixField new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newFunction [

	<generated>
	^ self add: SmallChatFamixFunction new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newImport [

	<generated>
	^ self add: SmallChatFamixImport new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newInterface [

	<generated>
	^ self add: SmallChatFamixInterface new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newJSXComponent [

	<generated>
	^ self add: SmallChatFamixJSXComponent new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newMethod [

	<generated>
	^ self add: SmallChatFamixMethod new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newModule [

	<generated>
	^ self add: SmallChatFamixModule new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newParameter [

	<generated>
	^ self add: SmallChatFamixParameter new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newProject [

	<generated>
	^ self add: SmallChatFamixProject new
]

{ #category : 'entity creation' }
SmallChatFamixTEntityCreator >> newTypeAlias [

	<generated>
	^ self add: SmallChatFamixTypeAlias new
]
