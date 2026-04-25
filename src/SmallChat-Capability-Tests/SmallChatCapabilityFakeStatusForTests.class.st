Class {
	#name : 'SmallChatCapabilityFakeStatusForTests',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'metadata' }
SmallChatCapabilityFakeStatusForTests class >> capabilityName [ ^ 'test.fake.status'
]

{ #category : 'metadata' }
SmallChatCapabilityFakeStatusForTests class >> description [ ^ 'Fake capability for registry tests.'
]

{ #category : 'metadata' }
SmallChatCapabilityFakeStatusForTests class >> isTestFixture [ ^ true
]

{ #category : 'execution' }
SmallChatCapabilityFakeStatusForTests class >> run: aCapabilityCall [ ^ SmallChatCapabilityResult text: 'ok'
]

{ #category : 'metadata' }
SmallChatCapabilityFakeStatusForTests class >> schema [ ^ nil
]
