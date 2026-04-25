"
Detector for stray Pharo UI debugger windows -- the modal stuck-on-the-UI-process kind that block the dev image. The capability dispatch path (SmallChatMCPCapabilityTransport>>dispatch:with:) consults #openWindows after every reply and prepends a single-line warning so the agent sees them out-of-band even though they are invisible to debug_sessions.

The debugger windows themselves live on the Morphic UI process; they are not registered with SmallChatDebugSessionRegistry and cannot be inspected via the debug.* capabilities. The agent must dismiss them via SmallChatDebuggerWatch closeAll once it has captured what it needs (e.g. via World imageForm).
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
	"Small {modelClass, presenterClass, title} Dictionary describing a stray debugger window.
	 presenterClass is omitted when the model already matches (no inner unwrapping)."
	| d presenterName |
	d := Dictionary new.
	d at: 'modelClass' put: ([ aMorph model class name asString ] on: Error do: [ :_ | '<error>' ]).
	presenterName := self presenterClassNameOf: ([ aMorph model ] on: Error do: [ :_ | nil ]).
	presenterName ifNotNil: [ d at: 'presenterClass' put: presenterName asString ].
	d at: 'title' put: ([ aMorph label asString ] on: Error do: [ :_ | '<no label>' ]).
	^ d
]

{ #category : 'private' }
SmallChatDebuggerWatch class >> isDebuggerClassName: aNameOrNil [
	"Accept a String or Symbol; nil-tolerant."
	aNameOrNil ifNil: [ ^ false ].
	^ aNameOrNil asString includesSubstring: 'Debugger'
]

{ #category : 'private' }
SmallChatDebuggerWatch class >> isDebuggerMorph: aMorph [
	"True if aMorph has a model whose class name contains 'Debugger', or whose
	 #presenter (Spec2 wrapping path: StWindowPresenter -> StDebugger) does.
	 Tolerant: any exception reading the chain -> false."
	| model |
	model := [ aMorph model ] on: Error do: [ :_ | nil ].
	model ifNil: [ ^ false ].
	(self isDebuggerClassName: model class name) ifTrue: [ ^ true ].
	^ self isDebuggerClassName: (self presenterClassNameOf: model)
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

{ #category : 'private' }
SmallChatDebuggerWatch class >> presenterClassNameOf: anObject [
	"Return the class name of anObject's #presenter, or nil if it does not respond or
	 throws. Probes one Spec2 wrapping level -- StWindowPresenter wraps StDebugger."
	(anObject respondsTo: #presenter) ifFalse: [ ^ nil ].
	^ [ anObject presenter class name ] on: Error do: [ :_ | nil ]
]
