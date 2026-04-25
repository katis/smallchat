Class {
	#name : 'SmallChatCapabilityRegistry',
	#superclass : 'Object',
	#classInstVars : [
		'default'
	],
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'accessing' }
SmallChatCapabilityRegistry class >> default [
	"Singleton instance. Reset via #reset for tests."
	^ default ifNil: [ default := self new ]
]

{ #category : 'accessing' }
SmallChatCapabilityRegistry class >> reset [
	"Drops the cached singleton. Test seam."
	default := nil
]

{ #category : 'accessing' }
SmallChatCapabilityRegistry >> allCapabilities [
	"Reflective discovery: every concrete SmallChatCapability subclass in
	 the image. Compile a new subclass and it appears here automatically."
	^ SmallChatCapability allSubclasses reject: [ :c | c isAbstract ]
]
