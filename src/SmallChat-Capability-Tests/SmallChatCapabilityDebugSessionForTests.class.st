Class {
	#name : 'SmallChatCapabilityDebugSessionForTests',
	#superclass : 'SmallChatCapability',
	#classInstVars : [
		'session'
	],
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'metadata' }
SmallChatCapabilityDebugSessionForTests class >> capabilityName [ ^ 'test.fake.debug-session'
]

{ #category : 'metadata' }
SmallChatCapabilityDebugSessionForTests class >> description [ ^ 'Returns a stub debugSession result. For tests.'
]

{ #category : 'execution' }
SmallChatCapabilityDebugSessionForTests class >> run: aCapabilityCall [
	^ SmallChatCapabilityResult debugSession: session
]

{ #category : 'metadata' }
SmallChatCapabilityDebugSessionForTests class >> schema [ ^ SmallChatCapabilitySchema empty
]

{ #category : 'metadata' }
SmallChatCapabilityDebugSessionForTests class >> session: aStub [
	"Test seam: set the session the fixture will return."
	session := aStub
]
