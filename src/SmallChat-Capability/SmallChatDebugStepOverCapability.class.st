Class {
	#name : 'SmallChatDebugStepOverCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatDebugStepOverCapability class >> capabilityName [ ^ 'debug.step-over'
]

{ #category : 'metadata' }
SmallChatDebugStepOverCapability class >> description [
	^ 'Advance one message-send past the current ictx of a captured debugger session, pausing at the new location. First call pops the handler+suspend frames (nil-substituting the signalling expression); subsequent calls advance further. The session keeps the same id and is marked stepped; follow up with debug_step_over/into, debug_proceed, or debug_terminate. debug_return is rejected on stepped sessions.'
]

{ #category : 'execution' }
SmallChatDebugStepOverCapability class >> run: aCapabilityCall [
	| sid session outcome |
	sid := aCapabilityCall arguments at: 'sessionId'.
	session := SmallChatDebugSessionRegistry default at: sid.
	outcome := SmallChatDebugEvaluator stepOver: session.
	outcome key = #result ifTrue: [ ^ SmallChatCapabilityResult text: outcome value ].
	outcome key = #debugSession ifTrue: [ ^ SmallChatCapabilityResult debugSession: outcome value ].
	self error: 'Unexpected step_over outcome: ' , outcome printString
]

{ #category : 'metadata' }
SmallChatDebugStepOverCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'sessionId' required: true description: 'Captured session id.'
]
