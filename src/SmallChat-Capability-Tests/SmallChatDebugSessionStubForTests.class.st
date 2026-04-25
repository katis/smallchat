Class {
	#name : 'SmallChatDebugSessionStubForTests',
	#superclass : 'Object',
	#instVars : [
		'id',
		'exception'
	],
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'instance creation' }
SmallChatDebugSessionStubForTests class >> id: anId exception: anException [
	"Stub that mimics SmallChatDebugSession enough for the MCP transport."
	^ self new setId: anId exception: anException
]

{ #category : 'accessing' }
SmallChatDebugSessionStubForTests >> debugSession [
	"Inner DebugSession-like stub returns self so we keep it self-contained.
	 Reply rendering catches the unprintable interruptedContext."
	^ self
]

{ #category : 'accessing' }
SmallChatDebugSessionStubForTests >> exception [ ^ exception
]

{ #category : 'accessing' }
SmallChatDebugSessionStubForTests >> id [ ^ id
]

{ #category : 'private' }
SmallChatDebugSessionStubForTests >> setId: anId exception: anException [
	id := anId.
	exception := anException
]
