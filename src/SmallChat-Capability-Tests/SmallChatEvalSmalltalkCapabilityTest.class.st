Class {
	#name : 'SmallChatEvalSmalltalkCapabilityTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'tests' }
SmallChatEvalSmalltalkCapabilityTest >> testRunCapturesDebugSessionOnException [
	| call result |
	SmallChatDebugSessionRegistry reset.
	call := SmallChatCapabilityCall name: 'eval.smalltalk' argumentsJson: '{"code":"1/0"}'.
	result := SmallChatEvalSmalltalkCapability run: call.
	self assert: result kind equals: #debugSession.
	self assert: result debugSession exception class name equals: #ZeroDivide.
	SmallChatDebugSessionRegistry reset
]

{ #category : 'tests' }
SmallChatEvalSmalltalkCapabilityTest >> testRunReturnsTextForSimpleExpression [
	| call result |
	call := SmallChatCapabilityCall name: 'eval.smalltalk' argumentsJson: '{"code":"3 + 4"}'.
	result := SmallChatEvalSmalltalkCapability run: call.
	self assert: result kind equals: #text.
	self assert: result text equals: '7'
]
