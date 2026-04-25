Class {
	#name : 'SmallChatDebugStepIntoCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatDebugStepIntoCapability class >> capabilityName [ ^ 'debug.step-into'
]

{ #category : 'metadata' }
SmallChatDebugStepIntoCapability class >> description [
	^ 'Step into the next message-send from the current ictx of a captured debugger session, pausing inside the called method. First call pops the handler+suspend frames (nil-substituting the signalling expression); subsequent calls advance further. The session keeps the same id and is marked stepped. Two calls are typically needed from a post-capture DoIt: the first reaches the next send-site, the second enters the callee.'
]

{ #category : 'execution' }
SmallChatDebugStepIntoCapability class >> run: aCapabilityCall [
	| sid session outcome |
	sid := aCapabilityCall arguments at: 'sessionId'.
	session := SmallChatDebugSessionRegistry default at: sid.
	outcome := SmallChatDebugEvaluator stepInto: session.
	outcome key = #result ifTrue: [ ^ SmallChatCapabilityResult text: outcome value ].
	outcome key = #debugSession ifTrue: [ ^ SmallChatCapabilityResult debugSession: outcome value ].
	self error: 'Unexpected step_into outcome: ' , outcome printString
]

{ #category : 'metadata' }
SmallChatDebugStepIntoCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'sessionId' required: true description: 'Captured session id.'
]
