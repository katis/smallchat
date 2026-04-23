Class {
	#name : 'SmallChatDebuggerWatch',
	#superclass : 'Object',
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

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
SmallChatDebuggerWatch class >> openWindowsFromMorphs: aCollection [
	"Filter seam: return descriptors for morphs whose model class name contains 'Debugger'."
	^ ((aCollection select: [ :m | self isDebuggerMorph: m ])
		collect: [ :m | self descriptorFor: m ]) asArray
]

{ #category : 'querying' }
SmallChatDebuggerWatch class >> openWindowsIn: aWorld [
	"Return an Array of descriptors for currently-visible debugger-ish
	 SystemWindows in aWorld. Tolerant: nil world yields #()."
	^ #()
]
