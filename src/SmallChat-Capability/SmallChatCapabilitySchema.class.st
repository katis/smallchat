Class {
	#name : 'SmallChatCapabilitySchema',
	#superclass : 'Object',
	#instVars : [
		'fields'
	],
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'instance creation' }
SmallChatCapabilitySchema class >> empty [
	"Schema with no fields. Use for capabilities that take no arguments."
	^ self new
]

{ #category : 'accessing' }
SmallChatCapabilitySchema >> fields [
	"Ordered collection of SmallChatCapabilitySchemaField. Order is the
	 declaration order; emitters preserve it for natural rendering."
	^ fields
]

{ #category : 'initialization' }
SmallChatCapabilitySchema >> initialize [
	super initialize.
	fields := OrderedCollection new
]
