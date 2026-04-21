"
Class-side singleton that tracks active SmallChatDebugSession objects
by id. Safety rails: TTL (default 10 min) reaped lazily on access,
and a max concurrent cap (default 8) that evicts the oldest and
terminates its parked Process when exceeded. Both bounds exist to
prevent the `evaluate raises -> forgotten debug session -> suspended
Process forever' leak.
"
Class {
	#name : 'SmallChatDebugSessionRegistry',
	#superclass : 'Object',
	#instVars : [
		'sessions',
		'maxOpen',
		'clock',
		'ttlMilliseconds'
	],
	#classVars : [
		'Default',
		'IdCounter'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing' }
SmallChatDebugSessionRegistry class >> default [
	Default ifNil: [ Default := self new ].
	^ Default
]

{ #category : 'accessing' }
SmallChatDebugSessionRegistry class >> nextId [
	IdCounter := (IdCounter ifNil: [ 0 ]) + 1.
	^ 'ds-' , IdCounter asString
]

{ #category : 'accessing' }
SmallChatDebugSessionRegistry class >> reset [
	Default ifNotNil: [ :r | r clear ].
	Default := nil.
	IdCounter := 0
]

{ #category : 'adding' }
SmallChatDebugSessionRegistry >> add: aSession [
	aSession createdAtMs: self clockNow.
	self evictStale.
	sessions add: aSession.
	[ sessions size > maxOpen ] whileTrue: [ self evictOldest ].
	^ aSession
]

{ #category : 'accessing' }
SmallChatDebugSessionRegistry >> at: anIdString [
	self evictStale.
	^ sessions detect: [ :s | s id = anIdString ]
]

{ #category : 'adding' }
SmallChatDebugSessionRegistry >> clear [
	[ sessions notEmpty ] whileTrue: [ self evictOldest ]
]

{ #category : 'accessing' }
SmallChatDebugSessionRegistry >> clock: aBlock [
	clock := aBlock
]

{ #category : 'private' }
SmallChatDebugSessionRegistry >> clockNow [
	^ clock value
]

{ #category : 'private' }
SmallChatDebugSessionRegistry >> evictOldest [
	| victim |
	sessions isEmpty ifTrue: [ ^ self ].
	victim := sessions removeFirst.
	victim process ifNotNil: [ :p | p isTerminated ifFalse: [ p terminate ] ]
]

{ #category : 'private' }
SmallChatDebugSessionRegistry >> evictStale [
	| now |
	now := self clockNow.
	[ sessions notEmpty and: [ (now - sessions first createdAtMs) > ttlMilliseconds ] ]
		whileTrue: [ self evictOldest ]
]

{ #category : 'initialization' }
SmallChatDebugSessionRegistry >> initialize [
	super initialize.
	sessions := OrderedCollection new.
	maxOpen := 8.
	ttlMilliseconds := 600000.
	clock := [ Time millisecondClockValue ]
]

{ #category : 'accessing' }
SmallChatDebugSessionRegistry >> maxOpen [
	^ maxOpen
]

{ #category : 'accessing' }
SmallChatDebugSessionRegistry >> maxOpen: anInteger [
	maxOpen := anInteger
]

{ #category : 'removing' }
SmallChatDebugSessionRegistry >> remove: aSession [
	sessions remove: aSession ifAbsent: [ nil ]
]

{ #category : 'accessing' }
SmallChatDebugSessionRegistry >> sessionsSnapshot [
	self evictStale.
	^ sessions copy
]

{ #category : 'accessing' }
SmallChatDebugSessionRegistry >> size [
	self evictStale.
	^ sessions size
]

{ #category : 'accessing' }
SmallChatDebugSessionRegistry >> ttlMilliseconds [
	^ ttlMilliseconds
]

{ #category : 'accessing' }
SmallChatDebugSessionRegistry >> ttlMilliseconds: anInteger [
	ttlMilliseconds := anInteger
]
