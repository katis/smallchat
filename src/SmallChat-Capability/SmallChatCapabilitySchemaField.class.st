Class {
	#name : 'SmallChatCapabilitySchemaField',
	#superclass : 'Object',
	#instVars : [
		'name',
		'type',
		'required',
		'description',
		'itemsType'
	],
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'instance creation' }
SmallChatCapabilitySchemaField class >> name: aName type: aTypeSymbol required: aBoolean description: aDescriptionString [
	"Construct a scalar field. Type is one of #string #integer #boolean #number;
	 array/object types arrive as the schema DSL grows."
	^ self new
		setName: aName type: aTypeSymbol required: aBoolean description: aDescriptionString
]

{ #category : 'emitting' }
SmallChatCapabilitySchemaField >> asJsonSchemaProperty [
	"Per-property dict that goes under #properties in the parent object.
	 Emits #items only for #array fields (the only context where it's defined)."
	| dict |
	dict := Dictionary new
		at: 'type' put: type asString;
		at: 'description' put: description;
		yourself.
	type = #array ifTrue: [
		dict at: 'items' put: (Dictionary new at: 'type' put: itemsType asString; yourself) ].
	^ dict
]

{ #category : 'accessing' }
SmallChatCapabilitySchemaField >> description [ ^ description
]

{ #category : 'accessing' }
SmallChatCapabilitySchemaField >> itemsType [ ^ itemsType
]

{ #category : 'accessing' }
SmallChatCapabilitySchemaField >> name [ ^ name
]

{ #category : 'accessing' }
SmallChatCapabilitySchemaField >> required [ ^ required
]

{ #category : 'private' }
SmallChatCapabilitySchemaField >> setItemsType: aSymbol [
	"Inner element type for #array fields; nil otherwise."
	itemsType := aSymbol.
	^ self
]

{ #category : 'private' }
SmallChatCapabilitySchemaField >> setName: aName type: aTypeSymbol required: aBoolean description: aDescriptionString [
	name := aName.
	type := aTypeSymbol.
	required := aBoolean.
	description := aDescriptionString.
	^ self
]

{ #category : 'accessing' }
SmallChatCapabilitySchemaField >> type [ ^ type
]
