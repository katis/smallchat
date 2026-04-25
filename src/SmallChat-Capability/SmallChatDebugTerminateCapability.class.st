Class {
	#name : 'SmallChatDebugTerminateCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatDebugTerminateCapability class >> capabilityName [ ^ 'debug.terminate'
]

{ #category : 'metadata' }
SmallChatDebugTerminateCapability class >> description [
	^ 'Drop a captured debugger session and terminate its parked process. Use when the captured state isn''t worth investigating further or when cleanup is needed.'
]

{ #category : 'execution' }
SmallChatDebugTerminateCapability class >> run: aCapabilityCall [
	| args sid session |
	args := aCapabilityCall arguments.
	sid := args at: 'sessionId'.
	session := SmallChatDebugSessionRegistry default at: sid.
	session process ifNotNil: [ :p | p isTerminated ifFalse: [ p terminate ] ].
	SmallChatDebugSessionRegistry default remove: session.
	^ SmallChatCapabilityResult text: 'Terminated debug session: ' , sid
]

{ #category : 'metadata' }
SmallChatDebugTerminateCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'sessionId' required: true description: 'Debug session id to terminate.'
]
