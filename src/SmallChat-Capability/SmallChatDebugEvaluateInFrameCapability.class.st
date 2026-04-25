Class {
	#name : 'SmallChatDebugEvaluateInFrameCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatDebugEvaluateInFrameCapability class >> capabilityName [ ^ 'debug.evaluate'
]

{ #category : 'metadata' }
SmallChatDebugEvaluateInFrameCapability class >> description [
	^ 'Evaluate a Smalltalk expression in the context of a captured frame. `self`, args, and temps of that frame are in scope -- ideal for probing state.'
]

{ #category : 'execution' }
SmallChatDebugEvaluateInFrameCapability class >> run: aCapabilityCall [
	| args sid idx expr session stack ctx result |
	args := aCapabilityCall arguments.
	sid := args at: 'sessionId'.
	idx := args at: 'index'.
	expr := args at: 'expression'.
	session := SmallChatDebugSessionRegistry default at: sid.
	stack := session debugSession stack.
	(idx < 0 or: [ idx >= stack size ]) ifTrue: [ ^ SmallChatCapabilityResult text: 'frame index ' , idx asString , ' out of range' ].
	ctx := stack at: idx + 1.
	result := OpalCompiler new
		source: expr;
		context: ctx;
		receiver: ctx receiver;
		evaluate.
	^ SmallChatCapabilityResult text: result printString
]

{ #category : 'metadata' }
SmallChatDebugEvaluateInFrameCapability class >> schema [
	^ SmallChatCapabilitySchema empty
		string: 'sessionId' required: true description: 'Captured session id.';
		integer: 'index' required: true description: 'Stack index for the evaluation context.';
		string: 'expression' required: true description: 'Smalltalk expression to evaluate.'
]
