"
Session configuration for SmallChat-LM clients. Class-side state so a
caller can do `SmallChatConfig baseUrl: '...'` once per session; first
read falls back to an environment variable, then to a hard-coded default.

Env vars:
  SMALLCHAT_LM_BASE_URL   default http://127.0.0.1:8000
  SMALLCHAT_LM_MODEL      default Qwen3.6-35B-A3B-nvfp4
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
	^ ModelName ifNil: [ ModelName := self envAt: 'SMALLCHAT_LM_MODEL' ifAbsent: 'Qwen3.6-35B-A3B-nvfp4' ]
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
SmallChatConfig class >> systemPromptOverride [
	"Explicit override for the chat system prompt, or nil to defer to the
	 bound workspace's defaultSystemPrompt. Reads SystemPrompt class var
	 (test-stubbed via #systemPromptOverride:, or set by a host) first;
	 falls back to SMALLCHAT_LM_SYSTEM_PROMPT env. Empty/missing env yields
	 nil so the session can pick up the workspace prompt."
	^ SystemPrompt ifNil: [
		| env |
		env := self envAt: 'SMALLCHAT_LM_SYSTEM_PROMPT' ifAbsent: nil.
		SystemPrompt := (env isNil or: [ env isEmpty ]) ifTrue: [ nil ] ifFalse: [ env ] ]
]

{ #category : 'accessing' }
SmallChatConfig class >> systemPromptOverride: aStringOrNil [
	"Set or clear the explicit override. Tests set + restore around their
	 own assertions; nil reverts to env-or-nil on the next read."
	SystemPrompt := aStringOrNil
]

{ #category : 'accessing' }
SmallChatConfig class >> temperature [
	^ 0.7
]

{ #category : 'class initialization' }
SmallChatConfig >> reset [
	BaseUrl := nil.
	ModelName := nil.
	SystemPrompt := nil.
	ApiKey := nil
]
