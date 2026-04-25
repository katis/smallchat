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

{ #category : 'accessing' }
SmallChatCapabilityRegistry >> capabilityNamed: aString [
	"Look up a capability class by its agent-facing identifier. Returns
	 nil if no concrete subclass matches -- transports decide whether to
	 surface that as an error or fall through to a legacy registry."
	^ self allCapabilities detect: [ :c | c capabilityName = aString ] ifNone: [ nil ]
]

{ #category : 'execution' }
SmallChatCapabilityRegistry >> run: aName with: aCall [
	"Dispatch aCall to the named capability under the universal cross-cutting
	 wrap. Returns nil for unknown names so transports can fall through.
	 Wrap captures uncaught exceptions and rewrites them as #error results."
	| cap |
	cap := self capabilityNamed: aName.
	cap ifNil: [ ^ nil ].
	^ [ cap run: aCall ]
		on: Error
		do: [ :e |
			SmallChatCapabilityResult error:
				'Error: ' , e class name , ' ' , (e messageText ifNil: [ '' ]) ]
]
