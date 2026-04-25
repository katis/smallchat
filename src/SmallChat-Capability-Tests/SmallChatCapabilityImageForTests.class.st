Class {
	#name : 'SmallChatCapabilityImageForTests',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'metadata' }
SmallChatCapabilityImageForTests class >> capabilityName [ ^ 'test.fake.image'
]

{ #category : 'metadata' }
SmallChatCapabilityImageForTests class >> description [ ^ 'Returns a tiny PNG-prefix byte array.'
]

{ #category : 'execution' }
SmallChatCapabilityImageForTests class >> run: aCapabilityCall [
	^ SmallChatCapabilityResult image: #(137 80 78 71) asByteArray mimeType: 'image/png'
]

{ #category : 'metadata' }
SmallChatCapabilityImageForTests class >> schema [ ^ SmallChatCapabilitySchema empty
]
