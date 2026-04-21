"
Per-evaluation holder shared between the fork that runs user code and
the caller blocked on state sem wait. Survives across resume cycles
on the same fork (debug_return/debug_proceed/debug_restart reset the
sem+outcome in place rather than allocating a new fork).
"
Class {
	#name : 'SmallChatDebugEvaluationState',
	#superclass : 'Object',
	#instVars : [
		'sem',
		'outcome'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing' }
SmallChatDebugEvaluationState >> outcome [
	^ outcome
]

{ #category : 'accessing' }
SmallChatDebugEvaluationState >> outcome: anAssoc [
	outcome := anAssoc
]

{ #category : 'lifecycle' }
SmallChatDebugEvaluationState >> reset [
	sem := Semaphore new.
	outcome := nil
]

{ #category : 'accessing' }
SmallChatDebugEvaluationState >> sem [
	^ sem
]

{ #category : 'accessing' }
SmallChatDebugEvaluationState >> sem: aSemaphore [
	sem := aSemaphore
]
