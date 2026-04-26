Class {
	#name : 'SmallChatAgentProfile',
	#superclass : 'Object',
	#instVars : [
		'name',
		'modelName',
		'systemPrompt'
	],
	#classVars : [
		'Profiles'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatAgentProfile class >> availableModels [
	"The model names the editor offers in its drop-list. Single source of
	 truth -- new profiles default to the first entry, and the registry's
	 seed clamps unknown values to it."
	^ #('Qwen3.6-27B-MLX-8bit' 'Qwen3.6-35B-A3B-nvfp4')
]

{ #category : 'initialization' }
SmallChatAgentProfile >> initialize [
	super initialize.
	modelName := self class availableModels first.
	systemPrompt := ''
]

{ #category : 'accessing' }
SmallChatAgentProfile >> modelName [
	^ modelName
]

{ #category : 'accessing' }
SmallChatAgentProfile >> name [
	^ name
]

{ #category : 'accessing' }
SmallChatAgentProfile >> systemPrompt [
	^ systemPrompt
]
