"
Session configuration for SmallChat-LM clients. Class-side state so a
caller can do `SmallChatConfig baseUrl: '...'` once per session; first
read falls back to an environment variable, then to a hard-coded default.

Env vars:
  SMALLCHAT_LM_BASE_URL   default http://localhost:1234
  SMALLCHAT_LM_MODEL      default qwen3.6-35b-a3b

maxTokens and temperature are not parameterised yet -- promote them to
class vars (and env) when a caller needs per-session override.
"
Class {
	#name : 'SmallChatConfig',
	#superclass : 'Object',
	#classVars : [
		'BaseUrl',
		'ModelName'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatConfig class >> baseUrl [
	^ BaseUrl ifNil: [ BaseUrl := self envAt: 'SMALLCHAT_LM_BASE_URL' ifAbsent: 'http://localhost:1234' ]
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
	^ ModelName ifNil: [ ModelName := self envAt: 'SMALLCHAT_LM_MODEL' ifAbsent: 'qwen3.6-35b-a3b' ]
]

{ #category : 'accessing' }
SmallChatConfig class >> modelName: aString [
	ModelName := aString
]

{ #category : 'class initialization' }
SmallChatConfig class >> reset [
	BaseUrl := nil.
	ModelName := nil
]

{ #category : 'accessing' }
SmallChatConfig class >> temperature [
	^ 0.7
]
