"
Detects stray Pharo UI debugger windows in the live World and lets the
MCP agent notice them.

SmallChatDebugEvaluator catches uncaught exceptions on its own fork into a
captured SmallChatDebugSession, but exceptions raised on *other* processes
(the Morphic UI process, user-spawned forks, Morphic step methods,
UIManager default defer: blocks) fall through to Pharo's default debug-
request path and open an StDebugger window. That window sits on the UI
process waiting for a human who isn't there. The MCP reader never sees it.

The registry path (SmallChatToolRegistry>>run:with:) consults `openWindows`
after each tool call and prepends a warning to the reply if any stray
debugger windows are present. `closeAll` is a helper the agent can invoke
via `evaluate` once it has seen the warning.

The filter is tolerant: nil world (SMALLCHAT_NO_GUI=1), DNU on `model`,
`label` faults -- all yield an empty result or a best-effort descriptor
rather than throwing. The watcher is called from the reader path and MUST
NOT throw.

Matches any SystemWindow whose `model` class name includes the substring
'Debugger'. This covers StDebugger and StMorphicDebugSession today, and
any future debugger-presenter class that follows the Pharo naming
convention.
"
Class {
	#name : 'SmallChatDebuggerWatch',
	#superclass : 'Object',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'actions' }
SmallChatDebuggerWatch class >> closeAll [
	"Dismiss every stray debugger window in the live UI world. Best-effort: errors
	 on individual deletes are swallowed so one bad morph cannot block the rest.
	 Returns the number of windows dismissed."
	| world count |
	world := Smalltalk at: #World ifAbsent: [ nil ].
	world ifNil: [ ^ 0 ].
	count := 0.
	world submorphs copy do: [ :m |
		(self isDebuggerMorph: m) ifTrue: [
			[ m delete. count := count + 1 ] on: Error do: [ :_ | nil ] ] ].
	^ count
]

{ #category : 'private' }
SmallChatDebuggerWatch class >> descriptorFor: aMorph [
	"Small {modelClass, title} Dictionary describing a stray debugger window."
	^ Dictionary new
		at: 'modelClass' put: aMorph model class name asString;
		at: 'title' put: aMorph label asString;
		yourself
]

{ #category : 'private' }
SmallChatDebuggerWatch class >> isDebuggerMorph: aMorph [
	"True if aMorph has a model whose class name contains 'Debugger'.
	 Tolerant: any exception reading the model (DNU, printer fault) -> false."
	| name |
	name := [ aMorph model class name asString ] on: Error do: [ :_ | nil ].
	name ifNil: [ ^ false ].
	^ name includesSubstring: 'Debugger'
]

{ #category : 'querying' }
SmallChatDebuggerWatch class >> openWindows [
	"Descriptors for stray debugger windows in the live UI world. #() in headless mode."
	^ self openWindowsIn: (Smalltalk at: #World ifAbsent: [ nil ])
]

{ #category : 'querying' }
SmallChatDebuggerWatch class >> openWindowsFromMorphs: aCollection [
	"Filter seam: return descriptors for morphs whose model class name contains 'Debugger'."
	^ ((aCollection select: [ :m | self isDebuggerMorph: m ])
		collect: [ :m | self descriptorFor: m ]) asArray
]

{ #category : 'querying' }
SmallChatDebuggerWatch class >> openWindowsIn: aWorld [
	"Top-level: return descriptors for currently-visible debugger-ish SystemWindows
	 under aWorld. Nil (headless mode) -> #()."
	aWorld ifNil: [ ^ #() ].
	^ self openWindowsFromMorphs: aWorld submorphs
]
