Class {
	#name : 'SmallChatCapabilitySchemaField',
	#superclass : 'Object',
	#instVars : [
		'name',
		'type',
		'required',
		'description'
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
	"The per-property dict that goes under #properties in the parent object."
	^ Dictionary new
		at: 'type' put: type asString;
		at: 'description' put: description;
		yourself
]

{ #category : 'accessing' }
SmallChatCapabilitySchemaField >> description [ ^ description
]

{ #category : 'accessing' }
SmallChatCapabilitySchemaField >> name [ ^ name
]

{ #category : 'accessing' }
SmallChatCapabilitySchemaField >> required [ ^ required
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
