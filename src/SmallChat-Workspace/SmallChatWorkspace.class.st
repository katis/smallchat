Class {
	#name : 'SmallChatWorkspace',
	#superclass : 'Object',
	#instVars : [
		'name'
	],
	#category : 'SmallChat-Workspace',
	#package : 'SmallChat-Workspace'
}

{ #category : 'accessing' }
SmallChatWorkspace class >> kind [
	"Symbol identifying the workspace kind, e.g. #pharo or #ts. Class-side
	 because the registry needs it before instantiation."
	^ self subclassResponsibility
]

{ #category : 'accessing' }
SmallChatWorkspace >> describeAsDict [
	"A Dictionary describing this workspace, suitable for JSON encoding by
	 workspace.* capabilities. Subclasses extend the result with their own
	 keys (path, branch, attachedAt, ...) but always include name + kind."
	^ Dictionary new
		at: 'name' put: (self name ifNil: [ '<unnamed>' ]);
		at: 'kind' put: self kind asString;
		yourself
]

{ #category : 'accessing' }
SmallChatWorkspace >> kind [
	"Symbol identifying the workspace kind. Delegates to the class."
	^ self class kind
]

{ #category : 'accessing' }
SmallChatWorkspace >> name [
	"Agent-facing identifier for this workspace."
	^ name
]

{ #category : 'accessing' }
SmallChatWorkspace >> name: aString [
	name := aString
]

{ #category : 'lifecycle' }
SmallChatWorkspace >> shutdown [
	"Tear down any external resources owned by this workspace. Default is
	 a no-op (Pharo workspace owns nothing detachable)."
	^ self
]
