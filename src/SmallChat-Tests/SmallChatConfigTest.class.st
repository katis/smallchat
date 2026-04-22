"
Class-side config is process-global, so save-and-restore around every test.
"
Class {
	#name : 'SmallChatConfigTest',
	#superclass : 'TestCase',
	#instVars : [
		'savedBaseUrl',
		'savedModelName'
	],
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'running' }
SmallChatConfigTest >> setUp [
	super setUp.
	savedBaseUrl := SmallChatConfig baseUrl.
	savedModelName := SmallChatConfig modelName
]

{ #category : 'running' }
SmallChatConfigTest >> tearDown [
	SmallChatConfig baseUrl: savedBaseUrl.
	SmallChatConfig modelName: savedModelName.
	super tearDown
]

{ #category : 'tests' }
SmallChatConfigTest >> testApiKeyNilWhenEnvUnset [
	"Reset the cached apiKey and ensure no env override interferes."
	| envApiKey savedApiKey |
	envApiKey := OSEnvironment current at: 'SMALLCHAT_LM_API_KEY' ifAbsent: [ nil ].
	envApiKey isNil ifFalse: [
		self skip: 'SMALLCHAT_LM_API_KEY is set in this environment' ].
	savedApiKey := SmallChatConfig apiKey.
	[ SmallChatConfig apiKey: nil.
	  self assert: SmallChatConfig apiKey isNil ]
		ensure: [ SmallChatConfig apiKey: savedApiKey ]
]

{ #category : 'tests' }
SmallChatConfigTest >> testBaseUrlIsNonEmptyString [
	self assert: SmallChatConfig baseUrl isString.
	self deny: SmallChatConfig baseUrl isEmpty
]

{ #category : 'tests' }
SmallChatConfigTest >> testBaseUrlOverride [
	SmallChatConfig baseUrl: 'http://example.com:8000'.
	self assert: SmallChatConfig baseUrl equals: 'http://example.com:8000'
]

{ #category : 'tests' }
SmallChatConfigTest >> testDefaultBaseUrlPointsAtLocalOMLX [
	"Reset the cached baseUrl and ensure no env override interferes."
	| envBaseUrl |
	envBaseUrl := OSEnvironment current at: 'SMALLCHAT_LM_BASE_URL' ifAbsent: [ nil ].
	envBaseUrl isNil ifFalse: [
		self skip: 'SMALLCHAT_LM_BASE_URL is set in this environment' ].
	SmallChatConfig baseUrl: nil.
	self assert: SmallChatConfig baseUrl equals: 'http://127.0.0.1:8000'
]

{ #category : 'tests' }
SmallChatConfigTest >> testModelNameIsNonEmptyString [
	self assert: SmallChatConfig modelName isString.
	self deny: SmallChatConfig modelName isEmpty
]

{ #category : 'tests' }
SmallChatConfigTest >> testModelNameOverride [
	SmallChatConfig modelName: 'custom-model'.
	self assert: SmallChatConfig modelName equals: 'custom-model'
]

{ #category : 'tests' }
SmallChatConfigTest >> testSystemPromptMentionsPharoExpert [
	self assert: (SmallChatConfig systemPrompt includesSubstring: 'Pharo 13 Smalltalk expert')
]
