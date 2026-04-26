Class {
	#name : 'SmallChatLMSessionTestRaisingClient',
	#superclass : 'Object',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'chat' }
SmallChatLMSessionTestRaisingClient >> complete: aConversation [
  ^ Error signal: 'boom non-stream'
]

{ #category : 'chat' }
SmallChatLMSessionTestRaisingClient >> complete: aConversation onDelta: aBlock [
  ^ Error signal: 'boom'
]
