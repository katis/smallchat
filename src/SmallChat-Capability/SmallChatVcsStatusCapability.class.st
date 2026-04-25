Class {
	#name : 'SmallChatVcsStatusCapability',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatVcsStatusCapability class >> capabilityName [ ^ 'vcs.status'
]

{ #category : 'private' }
SmallChatVcsStatusCapability class >> changesFor: aRepo [
	"Walk the workingCopyDiff tree and collect a flat array of
	 {target, changeType, definitionClass} dictionaries."
	| out walker skip |
	out := OrderedCollection new.
	skip := #('IceNoModification' 'IceEmptyNode').
	walker := nil.
	walker := [ :node |
		| typeName |
		typeName := node value class name.
		(skip includes: typeName) ifFalse: [
			| def |
			def := [ node value definition ] on: Error do: [ :_ | nil ].
			out add: (Dictionary new
				at: 'changeType' put: typeName;
				at: 'target' put: (self describeDefinition: def);
				at: 'definitionClass' put: ([ def class name ] on: Error do: [ :_ | '<unknown>' ]);
				yourself) ].
		([ node children ] on: Error do: [ :_ | #() ])
			do: [ :c | walker value: c ] ].
	[ walker value: aRepo workingCopyDiff tree ]
		on: Error do: [ :e |
			out add: (Dictionary new
				at: 'changeType' put: 'walk-failed';
				at: 'error' put: e messageText;
				yourself) ].
	^ out asArray
]

{ #category : 'private' }
SmallChatVcsStatusCapability class >> describeDefinition: aDef [
	"Best-effort human-readable identifier for an IceXxxDefinition."
	aDef ifNil: [ ^ '<no-def>' ].
	^ [
		(aDef respondsTo: #selector) ifTrue: [
			| meta |
			meta := (aDef respondsTo: #classIsMeta)
				ifTrue: [ aDef classIsMeta ifTrue: [ ' class' ] ifFalse: [ '' ] ]
				ifFalse: [ '' ].
			^ aDef className , meta , '>>#' , aDef selector ].
		(aDef respondsTo: #className) ifTrue: [ ^ aDef className ].
		(aDef respondsTo: #path) ifTrue: [ ^ aDef path printString ].
		'<unidentified>' ]
		on: Error
		do: [ :_ | '<unidentified>' ]
]

{ #category : 'metadata' }
SmallChatVcsStatusCapability class >> description [
	^ 'Working-copy + git status for the smallchat Iceberg repo. Reports the current branch, ahead/behind, whether the working copy diverges from HEAD, and a per-change summary (package, file kind, change type). Read-only.'
]

{ #category : 'private' }
SmallChatVcsStatusCapability class >> repository [
	| iceRepo |
	iceRepo := Smalltalk globals
		at: #IceRepository
		ifAbsent: [ ^ nil ].
	^ iceRepo registry
		detect: [ :r | ([ r name ] on: Error do: [ :_ | nil ]) = 'smallchat' ]
		ifNone: [ nil ]
]

{ #category : 'execution' }
SmallChatVcsStatusCapability class >> run: aCapabilityCall [
	"Migrated from SmallChatStatusTool>>run:; helpers copied class-side."
	| repo result |
	repo := self repository.
	repo ifNil: [
		^ SmallChatCapabilityResult text: 'No Iceberg repo named "smallchat" registered. Run `just rebuild-mcp` to bring the dev image up.' ].
	result := Dictionary new
		at: 'name' put: repo name;
		at: 'location' put: repo location fullName;
		at: 'subdirectory' put: repo subdirectory;
		at: 'branch' put: ([ repo branchName ] on: Error do: [ :e | '<error: ' , e messageText , '>' ]);
		at: 'isModified' put: repo workingCopy isModified;
		at: 'changes' put: (self changesFor: repo);
		yourself.
	^ SmallChatCapabilityResult text: (STONJSON toString: result)
]

{ #category : 'metadata' }
SmallChatVcsStatusCapability class >> schema [ ^ SmallChatCapabilitySchema empty
]
