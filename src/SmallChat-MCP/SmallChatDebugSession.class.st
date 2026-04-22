"
Value object wrapping a SindarinDebugger + DebugSession + parked
Process captured when user code raised an uncaught exception.
Registered in SmallChatDebugSessionRegistry by id; consumed by the
debug_* MCP tools.

resumeValue is set by debug_return (via SmallChatDebugEvaluator
resume:with:) just before the parked fork is resumed. state points
at the shared SmallChatDebugEvaluationState so debug_return / _proceed
/ _restart can reset the sem, resume the fork, and wait for the
fork's next outcome (success or a fresh debug session).
"
Class {
	#name : 'SmallChatDebugSession',
	#superclass : 'Object',
	#instVars : [
		'id',
		'sindarin',
		'debugSession',
		'exception',
		'process',
		'createdAtMs',
		'state',
		'resumeValue',
		'stepped'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing' }
SmallChatDebugSession >> createdAtMs [
	^ createdAtMs
]

{ #category : 'accessing' }
SmallChatDebugSession >> createdAtMs: aNumber [
	createdAtMs := aNumber
]

{ #category : 'accessing' }
SmallChatDebugSession >> debugSession [
	^ debugSession
]

{ #category : 'accessing' }
SmallChatDebugSession >> debugSession: aSession [
	debugSession := aSession
]

{ #category : 'accessing' }
SmallChatDebugSession >> exception [
	^ exception
]

{ #category : 'accessing' }
SmallChatDebugSession >> exception: anException [
	exception := anException
]

{ #category : 'accessing' }
SmallChatDebugSession >> id [
	^ id
]

{ #category : 'accessing' }
SmallChatDebugSession >> id: aString [
	id := aString
]

{ #category : 'accessing' }
SmallChatDebugSession >> process [
	^ process
]

{ #category : 'accessing' }
SmallChatDebugSession >> process: aProcess [
	process := aProcess
]

{ #category : 'accessing' }
SmallChatDebugSession >> resumeValue [
	^ resumeValue
]

{ #category : 'accessing' }
SmallChatDebugSession >> resumeValue: anObject [
	resumeValue := anObject
]

{ #category : 'accessing' }
SmallChatDebugSession >> sindarin [
	^ sindarin
]

{ #category : 'accessing' }
SmallChatDebugSession >> sindarin: aSindarin [
	sindarin := aSindarin
]

{ #category : 'accessing' }
SmallChatDebugSession >> state [
	^ state
]

{ #category : 'accessing' }
SmallChatDebugSession >> state: aState [
	state := aState
]

{ #category : 'accessing' }
SmallChatDebugSession >> stepped [
	^ stepped == true
]

{ #category : 'accessing' }
SmallChatDebugSession >> stepped: aBoolean [
    stepped := aBoolean
]
