Class {
	#name : 'SmallChatLMSessionTestStubCancellable',
	#superclass : 'Object',
	#instVars : [
		'cancelCount'
	],
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'cancellation' }
SmallChatLMSessionTestStubCancellable >> cancel [
  cancelCount := cancelCount + 1
]

{ #category : 'accessing' }
SmallChatLMSessionTestStubCancellable >> cancelCount [ ^ cancelCount
]

{ #category : 'initialization' }
SmallChatLMSessionTestStubCancellable >> initialize [
  super initialize.
  cancelCount := 0
]
