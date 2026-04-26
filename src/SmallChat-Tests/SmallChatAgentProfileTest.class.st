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
SmallChatAgentProfileTest >> testModelNameRejectsUnknown [
	"modelName: must reject names outside availableModels so the editor
	 can't persist a value the drop-list doesn't offer."
	| p |
	p := SmallChatAgentProfile new.
	self should: [ p modelName: 'gpt-9' ] raise: Error
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

{ #category : 'tests' }
SmallChatAgentProfileTest >> testRegistryAddLookupRemove [
	"Class-side registry holds added profiles, looks them up by name,
	 removes by name. Reset gives a clean baseline."
	| profile |
	SmallChatAgentProfile reset.
	profile := SmallChatAgentProfile new name: 'alpha-fixture'; yourself.
	SmallChatAgentProfile add: profile.
	self assert: (SmallChatAgentProfile named: 'alpha-fixture') == profile.
	self assert: ((SmallChatAgentProfile all collect: [ :p | p name ]) includes: 'alpha-fixture').
	SmallChatAgentProfile removeNamed: 'alpha-fixture'.
	self assert: (SmallChatAgentProfile named: 'alpha-fixture' ifAbsent: [ #absent ]) equals: #absent
]

{ #category : 'tests' }
SmallChatAgentProfileTest >> testRegistryRejectsDuplicate [
	"add: with a name already in the registry raises so the editor never
	 ends up with two profiles under the same key."
	SmallChatAgentProfile reset.
	SmallChatAgentProfile add: (SmallChatAgentProfile new name: 'beta-fixture'; yourself).
	self should: [
		SmallChatAgentProfile add:
			(SmallChatAgentProfile new name: 'beta-fixture'; yourself) ]
		raise: Error
]

{ #category : 'tests' }
SmallChatAgentProfileTest >> testResetSeedsDefaultProfile [
	"After reset, the registry exposes a single 'Default' profile whose
	 model + system prompt mirror the current SmallChatConfig modelName +
	 SmallChatPharoWorkspace defaultSystemPrompt -- so a fresh image
	 rebuild always has the existing agent config available."
	| seeded |
	SmallChatAgentProfile reset.
	seeded := SmallChatAgentProfile all.
	self assert: seeded size equals: 1.
	self assert: seeded first name equals: 'Default'.
	self assert: seeded first modelName equals: SmallChatConfig modelName.
	self assert: seeded first systemPrompt equals: SmallChatPharoWorkspace defaultSystemPrompt
]
