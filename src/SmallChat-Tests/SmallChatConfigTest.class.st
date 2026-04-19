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
SmallChatConfigTest >> testModelNameIsNonEmptyString [
	self assert: SmallChatConfig modelName isString.
	self deny: SmallChatConfig modelName isEmpty
]

{ #category : 'tests' }
SmallChatConfigTest >> testModelNameOverride [
	SmallChatConfig modelName: 'custom-model'.
	self assert: SmallChatConfig modelName equals: 'custom-model'
]
