Class {
	#name : 'SmallChatCapabilityRegistry',
	#superclass : 'Object',
	#instVars : [
		'uiProcessProvider',
		'currentWorkspace',
		'mountedWorkspaces'
	],
	#classInstVars : [
		'default'
	],
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'accessing' }
SmallChatCapabilityRegistry class >> default [
	"Singleton instance. Reset via #reset for tests."
	^ default ifNil: [ default := self new ]
]

{ #category : 'accessing' }
SmallChatCapabilityRegistry class >> reset [
	"Drops the cached singleton. Test seam."
	default := nil
]

{ #category : 'accessing' }
SmallChatCapabilityRegistry >> allCapabilities [
	"Reflective discovery: every concrete SmallChatCapability subclass in
	 the image. Compile a new subclass and it appears here automatically."
	^ SmallChatCapability allSubclasses reject: [ :c | c isAbstract ]
]

{ #category : 'execution' }
SmallChatCapabilityRegistry >> applicabilityErrorFor: aCapabilityClass workspace: aWorkspace [
	"Structured error returned when a capability is dispatched against a
	 workspace whose kind it does not support. Names the capability, the
	 actual workspace + kind, the supported kinds, and the remediation."
	| supported |
	supported := (aCapabilityClass supportedWorkspaces collect: [ :s | s asString ]) asArray.
	^ 'Capability ' , aCapabilityClass capabilityName ,
		' is not applicable to workspace ' , (aWorkspace name ifNil: [ '<unnamed>' ]) ,
		' (kind: ' , aWorkspace kind asString , ').' ,
		' Supported kinds: [' , (Character space join: supported) , '].' ,
		' Attach a matching workspace via workspace.attach-ts.'
]

{ #category : 'accessing' }
SmallChatCapabilityRegistry >> capabilityNamed: aString [
	"Look up a capability class by its agent-facing identifier. Returns
	 nil if no concrete subclass matches -- transports decide whether to
	 surface that as an error or fall through to a legacy registry."
	^ self allCapabilities detect: [ :c | c capabilityName = aString ] ifNone: [ nil ]
]

{ #category : 'accessing' }
SmallChatCapabilityRegistry >> currentWorkspace [
	"The workspace this registry dispatches to when a capability call does
	 not name one explicitly. Defaults to the Pharo dev image."
	^ currentWorkspace ifNil: [ currentWorkspace := SmallChatPharoWorkspace default ]
]

{ #category : 'accessing' }
SmallChatCapabilityRegistry >> currentWorkspace: aWorkspace [
	currentWorkspace := aWorkspace
]

{ #category : 'accessing' }
SmallChatCapabilityRegistry >> mountedWorkspaces [
	"Workspaces this registry knows about. The Pharo workspace is always
	 the first entry; TS workspaces are appended via workspace.attach-ts."
	^ mountedWorkspaces ifNil: [
		mountedWorkspaces := OrderedCollection with: SmallChatPharoWorkspace default ]
]

{ #category : 'execution' }
SmallChatCapabilityRegistry >> run: aName with: aCall [
	"Dispatch aCall to the named capability under the universal cross-cutting
	 wrap. Returns nil for unknown names so transports can fall through.
	 Wrap (1) refuses to run on the Morphic UI process, (2) resumes any
	 Notification, (3) captures Errors as #error results, and (4) refuses
	 to run a capability whose #supportedWorkspaces does not include the
	 resolved workspace's kind."
	| cap ws |
	Processor activeProcess == self uiProcessProvider value
		ifTrue: [ self error: 'SmallChatCapability dispatch on UI process: ' , aName ].
	cap := self capabilityNamed: aName.
	cap ifNil: [ ^ nil ].
	ws := self workspaceFor: aCall.
	(cap supportedWorkspaces includes: ws kind) ifFalse: [
		^ SmallChatCapabilityResult error: (self applicabilityErrorFor: cap workspace: ws) ].
	^ [ [ cap run: aCall ]
			on: Notification
			do: [ :n | n resume ] ]
		on: Error
		do: [ :e |
			SmallChatCapabilityResult error:
				'Error: ' , e class name , ' ' , (e messageText ifNil: [ '' ]) ]
]

{ #category : 'accessing' }
SmallChatCapabilityRegistry >> uiProcessProvider [
	"Block returning the process that must NOT dispatch capabilities
	 (Morphic's UI process). Test seam."
	^ uiProcessProvider ifNil: [ uiProcessProvider := [ UIManager default uiProcess ] ]
]

{ #category : 'accessing' }
SmallChatCapabilityRegistry >> uiProcessProvider: aBlock [
	uiProcessProvider := aBlock
]

{ #category : 'execution' }
SmallChatCapabilityRegistry >> workspaceFor: aCall [
	"Resolve the workspace this call should dispatch against.
	 Per-call workspace overrides the registry default. Either way,
	 nil is impossible -- currentWorkspace lazily falls back to Pharo."
	^ aCall workspace ifNil: [ self currentWorkspace ]
]
