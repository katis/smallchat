Class {
	#name : 'SmallChatCapabilityTsOnlyForTests',
	#superclass : 'SmallChatCapability',
	#category : 'SmallChat-Capability-Tests',
	#package : 'SmallChat-Capability-Tests'
}

{ #category : 'metadata' }
SmallChatCapabilityTsOnlyForTests class >> capabilityName [ ^ 'test.ts.only'
]

{ #category : 'metadata' }
SmallChatCapabilityTsOnlyForTests class >> description [ ^ 'TS-only capability fixture for workspace-kind filtering tests.'
]

{ #category : 'metadata' }
SmallChatCapabilityTsOnlyForTests class >> isTestFixture [ ^ true
]

{ #category : 'execution' }
SmallChatCapabilityTsOnlyForTests class >> run: aCapabilityCall [ ^ SmallChatCapabilityResult text: 'ts-ran'
]

{ #category : 'metadata' }
SmallChatCapabilityTsOnlyForTests class >> schema [ ^ SmallChatCapabilitySchema empty
]

{ #category : 'metadata' }
SmallChatCapabilityTsOnlyForTests class >> supportedWorkspaces [ ^ #(#ts)
]
