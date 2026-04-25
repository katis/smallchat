Class {
	#name : 'SmallChatDebugFrameCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatDebugFrameCapability class >> capabilityName [ ^ 'debug.frame'
]

{ #category : 'metadata' }
SmallChatDebugFrameCapability class >> description [
	^ 'Detailed view of one frame: receiver, selector, args, temps, source.'
]

{ #category : 'execution' }
SmallChatDebugFrameCapability class >> run: aCapabilityCall [
	| args sid idx session stack ctx safePrint dict |
	args := aCapabilityCall arguments.
	sid := args at: 'sessionId'.
	idx := args at: 'index'.
	session := SmallChatDebugSessionRegistry default at: sid.
	stack := [ session debugSession stack ] on: Error do: [ :_ | #() ].
	(idx < 0 or: [ idx >= stack size ]) ifTrue: [
		^ SmallChatCapabilityResult text: (STONJSON toString: (Dictionary new
			at: 'error' put: 'frame index ' , idx asString , ' out of range';
			yourself)) ].
	ctx := stack at: idx + 1.
	safePrint := [ :obj | [ obj printString ] on: Error do: [ :_ | '<unprintable>' ] ].
	dict := Dictionary new
		at: 'index' put: idx;
		at: 'receiverClass' put: ([ ctx receiver class name asString ] on: Error do: [ :_ | '<unprintable>' ]);
		at: 'receiver' put: (safePrint value: ctx receiver);
		at: 'selector' put: ([ ctx method selector asString ] on: Error do: [ :_ | '<unprintable>' ]);
		at: 'args' put: ((ctx arguments collect: [ :a | safePrint value: a ]) asArray);
		at: 'temps' put: ([ | td |
			td := Dictionary new.
			ctx tempNames do: [ :n |
				td at: n put: (safePrint value: (ctx tempNamed: n)) ].
			td ] on: Error do: [ :_ | Dictionary new ]);
		at: 'source' put: ([ ctx method sourceCode ] on: Error do: [ :_ | '' ]);
		yourself.
	^ SmallChatCapabilityResult text: (STONJSON toString: dict)
]

{ #category : 'metadata' }
SmallChatDebugFrameCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'sessionId' required: true description: 'Captured session id.';
		integer: 'index' required: true description: 'Stack index (0 = signaller).'
]
