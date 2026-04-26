Class {
	#name : 'SmallChatAgentProfileTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatAgentProfileTest >> testNewProfileHasDefaults [
	"A fresh profile defaults its modelName to availableModels first, has
	 an empty systemPrompt and a nil name -- it's a draft until added to
	 the registry under a unique name."
	| profile |
	profile := SmallChatAgentProfile new.
	self assert: profile modelName equals: SmallChatAgentProfile availableModels first.
	self assert: profile systemPrompt equals: ''.
	self assert: profile name isNil
]
