Class {
	#name : 'SmallChatCapability',
	#superclass : 'Object',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'testing' }
SmallChatCapability class >> isAbstract [
	"True for the abstract base. Subclasses are concrete unless they
	 redefine this. Reflective discovery uses this to filter."
	^ self == SmallChatCapability
]
