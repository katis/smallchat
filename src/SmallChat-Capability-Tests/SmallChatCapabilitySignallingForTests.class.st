Class {
	#name : 'SmallChatCapabilitySignallingForTests',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'metadata' }
SmallChatCapabilitySignallingForTests class >> capabilityName [ ^ 'test.fake.signalling'
]

{ #category : 'metadata' }
SmallChatCapabilitySignallingForTests class >> description [ ^ 'Signals a Notification, then succeeds. For wrap tests.'
]

{ #category : 'metadata' }
SmallChatCapabilitySignallingForTests class >> isTestFixture [ ^ true
]

{ #category : 'execution' }
SmallChatCapabilitySignallingForTests class >> run: aCapabilityCall [
	"Signals a Notification (Pharo's default handler writes to stdout --
	 corruption hazard for MCP framing). Wrap must resume so the run completes."
	Notification signal: 'hello'.
	^ SmallChatCapabilityResult text: 'ok-after-notification'
]

{ #category : 'metadata' }
SmallChatCapabilitySignallingForTests class >> schema [ ^ SmallChatCapabilitySchema empty
]
