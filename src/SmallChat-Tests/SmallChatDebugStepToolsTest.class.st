Class {
	#name : 'SmallChatDebugStepToolsTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'running' }
SmallChatDebugStepToolsTest >> tearDown [
    SmallChatDebugSessionRegistry reset.
    super tearDown
]

{ #category : 'tests' }
SmallChatDebugStepToolsTest >> testSessionSteppedDefaultsToFalseAndRoundTrips [
    | s |
    s := SmallChatDebugSession new.
    self deny: s stepped.
    s stepped: true.
    self assert: s stepped.
    s stepped: false.
    self deny: s stepped
]
