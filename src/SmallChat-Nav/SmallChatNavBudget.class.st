Class {
	#name : 'SmallChatNavBudget',
	#superclass : 'Object',
	#instVars : [
		'size'
	],
	#classInstVars : [
		'Default'
	],
	#category : 'SmallChat-Nav',
	#package : 'SmallChat-Nav'
}

{ #category : 'accessing' }
SmallChatNavBudget class >> default [
	^ Default ifNil: [ Default := self new ]
]

{ #category : 'accessing' }
SmallChatNavBudget class >> reset [
	Default := nil
]

{ #category : 'accessing' }
SmallChatNavBudget >> size [
	^ size ifNil: [ size := 3200 ]
]

{ #category : 'accessing' }
SmallChatNavBudget >> size: anInteger [
	size := anInteger
]
