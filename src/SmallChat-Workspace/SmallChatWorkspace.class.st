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
