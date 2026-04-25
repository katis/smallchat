Class {
	#name : 'SmallChatDebugRestartCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatDebugRestartCapability class >> capabilityName [ ^ 'debug.restart'
]

{ #category : 'metadata' }
SmallChatDebugRestartCapability class >> description [
	^ 'Restart a frame of a captured debugger session, re-executing from its method entry with the same receiver/args. Default index is 0 (signaller). After a fix, restart the caller frame to retry.'
]

{ #category : 'execution' }
SmallChatDebugRestartCapability class >> run: aCapabilityCall [
	| args sid idx session outcome |
	args := aCapabilityCall arguments.
	sid := args at: 'sessionId'.
	idx := args at: 'index' ifAbsent: [ 0 ].
	session := SmallChatDebugSessionRegistry default at: sid.
	outcome := SmallChatDebugEvaluator restart: session index: idx.
	outcome key = #result ifTrue: [ ^ SmallChatCapabilityResult text: outcome value ].
	outcome key = #debugSession ifTrue: [ ^ SmallChatCapabilityResult debugSession: outcome value ].
	self error: 'Unexpected restart outcome: ' , outcome printString
]

{ #category : 'metadata' }
SmallChatDebugRestartCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'sessionId' required: true description: 'Captured session id.';
		integer: 'index' required: false description: 'Stack index to restart; defaults to 0 (signaller).'
]
