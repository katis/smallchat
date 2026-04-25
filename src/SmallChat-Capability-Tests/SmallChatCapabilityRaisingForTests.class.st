Class {
	#name : 'SmallChatCapabilityRaisingForTests',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'metadata' }
SmallChatCapabilityRaisingForTests class >> capabilityName [ ^ 'test.fake.raising'
]

{ #category : 'metadata' }
SmallChatCapabilityRaisingForTests class >> description [ ^ 'Always raises. For wrap tests.'
]

{ #category : 'execution' }
SmallChatCapabilityRaisingForTests class >> run: aCapabilityCall [
	"Always raises -- exercises the registry's exception capture wrap."
	self error: 'boom'
]

{ #category : 'metadata' }
SmallChatCapabilityRaisingForTests class >> schema [ ^ SmallChatCapabilitySchema empty
]
