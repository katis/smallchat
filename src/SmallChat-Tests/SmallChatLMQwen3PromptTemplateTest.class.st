Class {
	#name : 'SmallChatLMQwen3PromptTemplateTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatLMQwen3PromptTemplateTest >> testRendersAssistantTurnBeforeGenerationCue [
	"A mid-conversation assistant turn gets closed with <|im_end|>; the
	 final <|im_start|>assistant cue still prompts the next completion."
	| conv rendered closedAssistantTurn generationCue |
	conv := SmallChatLMConversation new
		addUser: 'hi';
		addAssistant: 'hello';
		addUser: 'again';
		yourself.
	rendered := SmallChatLMQwen3PromptTemplate new render: conv.
	closedAssistantTurn := String streamContents: [ :s |
		s nextPutAll: '<|im_start|>assistant'; nextPut: Character lf.
		s nextPutAll: 'hello<|im_end|>' ].
	generationCue := String streamContents: [ :s |
		s nextPutAll: '<|im_start|>assistant'; nextPut: Character lf ].
	self assert: (rendered includesSubstring: closedAssistantTurn).
	self assert: (rendered endsWith: generationCue)
]

{ #category : 'tests' }
SmallChatLMQwen3PromptTemplateTest >> testRendersQwen3Format [
	| conv template expected rendered |
	conv := SmallChatLMConversation new
		addSystem: 'You are helpful.';
		addUser: 'Hi';
		yourself.
	template := SmallChatLMQwen3PromptTemplate new.
	expected := String streamContents: [ :s |
		s nextPutAll: '<|im_start|>system'; nextPut: Character lf.
		s nextPutAll: 'You are helpful.<|im_end|>'; nextPut: Character lf.
		s nextPutAll: '<|im_start|>user'; nextPut: Character lf.
		s nextPutAll: 'Hi<|im_end|>'; nextPut: Character lf.
		s nextPutAll: '<|im_start|>assistant'; nextPut: Character lf ].
	rendered := template render: conv.
	self assert: rendered equals: expected
]

{ #category : 'tests' }
SmallChatLMQwen3PromptTemplateTest >> testStopTokens [
	self
		assert: SmallChatLMQwen3PromptTemplate new stopTokens
		equals: #('<|im_end|>')
]
