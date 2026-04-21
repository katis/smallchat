"
Fork-and-intercept runner. Evaluates arbitrary Smalltalk on its own
low-priority Process; an uncaught exception is captured into a
suspended SmallChatDebugSession (registered in
SmallChatDebugSessionRegistry) rather than flattened to a string or
propagated to the UIManager default debugger.

The caller -- the evaluate MCP tool, and opt-in run_tests -- blocks
on state sem wait, never on the fork itself, so the MCP reader is
free to service further calls (including debug_* tools targeting the
parked fork).

Resume paths -- resume:with: (used by debug_return/debug_proceed) and
restart:index: (used by debug_restart) -- pop the fork's stack above
the chosen context via DebugSession>>returnValue:from: /
unwindAndRestartToContext:, then `process resume` the parked fork.
Lines after `Processor activeProcess suspend' in captureException are
never reached.
"
Class {
	#name : 'SmallChatDebugEvaluator',
	#superclass : 'Object',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'evaluating' }
SmallChatDebugEvaluator class >> captureException: ex state: state [
	"Runs on the forked process, inside the outer `on: Exception do:` handler.
	 Builds a SmallChatDebugSession, registers it, signals the caller, then
	 parks the fork via Processor activeProcess suspend.

	 When a follow-up tool (debug_return / debug_terminate) runs, it pops the
	 fork's stack via DebugSession>>returnValue:from: targeting the signaler
	 context -- which discards this handler and suspend frame -- and resumes
	 the process. The fork then continues at the sender of the signalling
	 send, so execution behaves as if the signalling expression returned the
	 substituted value. Lines below the suspend are never reached."
	| ds sindarin session |
	ds := DebugSession named: 'smallchat-eval' on: ex startedAt: ex signalerContext.
	ds process: Processor activeProcess context: ex signalerContext.
	sindarin := SindarinDebugger attachTo: ds.
	session := SmallChatDebugSession new
		id: SmallChatDebugSessionRegistry nextId;
		exception: ex;
		debugSession: ds;
		sindarin: sindarin;
		process: Processor activeProcess;
		state: state;
		yourself.
	SmallChatDebugSessionRegistry default add: session.
	state outcome: #debugSession -> session.
	state sem signal.
	Processor activeProcess suspend
]

{ #category : 'evaluating' }
SmallChatDebugEvaluator class >> evaluate: aString [
	| state |
	state := SmallChatDebugEvaluationState new reset.
	[ self evaluateBlock: aString state: state ]
		forkAt: Processor lowIOPriority
		named: 'smallchat-eval'.
	state sem wait.
	^ state outcome
]

{ #category : 'evaluating' }
SmallChatDebugEvaluator class >> evaluateBlock: aString state: state [
	"Runs on the forked process. Normal path: set outcome to #result; signal sem.
	 Error path: build a SmallChatDebugSession, register it, signal sem, suspend."
	[ [ [ | r |
			r := OpalCompiler new source: aString; evaluate.
			state outcome: #result -> r printString.
			state sem signal ]
		  on: Notification
		  do: [ :n | n resume ] ]
		on: Exception
		do: [ :ex | self captureException: ex state: state ] ]
	  on: Error
	  do: [ :e |
		"Safety net: if our capture machinery itself fails, fall back to a string
		 outcome so the caller unblocks instead of dangling forever."
		state outcome: #result -> ('<debugger capture failed: ' , e class name , ' ' ,
			(e messageText ifNil: [ '' ]) , '>').
		state sem signal ]
]

{ #category : 'evaluating' }
SmallChatDebugEvaluator class >> restart: aSmallChatDebugSession index: anInteger [
	"Restart the frame at stack index anInteger (0 = signaler). Pops the stack
	 to that frame, restarts from its method entry, resumes the fork. The
	 fork then re-executes from that point; on re-raise it re-parks in a new
	 debug session."
	| state ctx |
	state := aSmallChatDebugSession state.
	state reset.
	SmallChatDebugSessionRegistry default remove: aSmallChatDebugSession.
	ctx := aSmallChatDebugSession debugSession stack at: anInteger + 1.
	aSmallChatDebugSession debugSession restart: ctx.
	aSmallChatDebugSession process resume.
	state sem wait.
	^ state outcome
]

{ #category : 'evaluating' }
SmallChatDebugEvaluator class >> resume: aSmallChatDebugSession with: aValue [
	"Wake a parked debug session, substituting aValue for the signalling
	 expression. Pops the fork's stack above the signaler context -- throwing
	 away our handler frame and suspend -- then resumes. Waits for the fork
	 to either complete or re-park in a new debug session, and returns the
	 resulting outcome association."
	| state ex |
	state := aSmallChatDebugSession state.
	state reset.
	ex := aSmallChatDebugSession exception.
	SmallChatDebugSessionRegistry default remove: aSmallChatDebugSession.
	aSmallChatDebugSession debugSession returnValue: aValue from: ex signalerContext.
	aSmallChatDebugSession process resume.
	state sem wait.
	^ state outcome
]
