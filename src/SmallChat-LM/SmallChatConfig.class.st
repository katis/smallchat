"
Session configuration for SmallChat-LM clients. Class-side state so a
caller can do `SmallChatConfig baseUrl: '...'` once per session; first
read falls back to an environment variable, then to a hard-coded default.

Env vars:
  SMALLCHAT_LM_BASE_URL   default http://127.0.0.1:8000
  SMALLCHAT_LM_MODEL      default qwen3.6-35b-a3b
  SMALLCHAT_LM_API_KEY    no default; nil/empty means no Authorization header

maxTokens and temperature are not parameterised yet -- promote them to
class vars (and env) when a caller needs per-session override.
"
Class {
	#name : 'SmallChatConfig',
	#superclass : 'Object',
	#classVars : [
		'ApiKey',
		'BaseUrl',
		'ModelName',
		'SystemPrompt'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatConfig class >> apiKey [
	"Returns the configured API key, or nil if none. Reads env on first access.
	 An unset / empty env var yields nil so callers can skip the Authorization header."
	^ ApiKey ifNil: [
		| env |
		env := self envAt: 'SMALLCHAT_LM_API_KEY' ifAbsent: nil.
		ApiKey := (env isNil or: [ env isEmpty ]) ifTrue: [ nil ] ifFalse: [ env ] ]
]

{ #category : 'accessing' }
SmallChatConfig class >> apiKey: aStringOrNil [
	ApiKey := aStringOrNil
]

{ #category : 'accessing' }
SmallChatConfig class >> baseUrl [
	^ BaseUrl ifNil: [ BaseUrl := self envAt: 'SMALLCHAT_LM_BASE_URL' ifAbsent: 'http://127.0.0.1:8000' ]
]

{ #category : 'accessing' }
SmallChatConfig class >> baseUrl: aString [
	BaseUrl := aString
]

{ #category : 'accessing' }
SmallChatConfig class >> defaultSystemPrompt [
	"Hard-coded default so the compiled Tonel file stays free of tricky
	 mixed-quote escapes. Built from pieces via streamContents:."
	^ String streamContents: [ :s |
		s nextPutAll: 'You are a Pharo 13 Smalltalk expert. You use best practices like Red-Green TDD, Intention-revealing selectors, Method protocols, Mandatory Class comments, '.
		s nextPut: $".
		s nextPutAll: 'Tell, don'.
		s nextPut: $'.
		s nextPutAll: 't ask'.
		s nextPut: $".
		s nextPutAll: ' and double dispatch. Use Live programming techniques, Code Critic for linting, and Iceberg for VCS operations.' ]
]

{ #category : 'private' }
SmallChatConfig class >> envAt: aKey ifAbsent: aDefault [
	^ OSEnvironment current at: aKey ifAbsent: [ aDefault ]
]

{ #category : 'accessing' }
SmallChatConfig class >> maxTokens [
	^ 1024
]

{ #category : 'accessing' }
SmallChatConfig class >> modelName [
	^ ModelName ifNil: [ ModelName := self envAt: 'SMALLCHAT_LM_MODEL' ifAbsent: 'qwen3.6-35b-a3b' ]
]

{ #category : 'accessing' }
SmallChatConfig class >> modelName: aString [
	ModelName := aString
]

{ #category : 'class initialization' }
SmallChatConfig class >> reset [
	BaseUrl := nil.
	ModelName := nil.
	SystemPrompt := nil.
	ApiKey := nil
]

{ #category : 'accessing' }
SmallChatConfig class >> systemPrompt [
	^ SystemPrompt ifNil: [ SystemPrompt := self envAt: 'SMALLCHAT_LM_SYSTEM_PROMPT' ifAbsent: self defaultSystemPrompt ]
]

{ #category : 'accessing' }
SmallChatConfig class >> systemPrompt: aString [
	SystemPrompt := aString
]

{ #category : 'accessing' }
SmallChatConfig class >> temperature [
	^ 0.7
]
