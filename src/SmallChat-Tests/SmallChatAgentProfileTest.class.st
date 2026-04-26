Class {
	#name : 'SmallChatAgentProfileTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatAgentProfileTest >> testAccessorsRoundTrip [
	"name:/modelName:/systemPrompt: store the value the getter returns. The
	 setters operate on a draft (no registry yet)."
	| p |
	p := SmallChatAgentProfile new.
	p name: 'alpha'.
	p modelName: 'Qwen3.6-27B-MLX-8bit'.
	p systemPrompt: 'hi'.
	self assert: p name equals: 'alpha'.
	self assert: p modelName equals: 'Qwen3.6-27B-MLX-8bit'.
	self assert: p systemPrompt equals: 'hi'
]

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
