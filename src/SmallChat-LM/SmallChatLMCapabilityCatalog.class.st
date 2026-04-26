Class {
	#name : 'SmallChatLMCapabilityCatalog',
	#superclass : 'Object',
	#instVars : [
		'workspace'
	],
	#classInstVars : [
		'default'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatLMCapabilityCatalog class >> default [
	"Singleton catalog scoped to the always-mounted Pharo workspace.
	 Reset via #reset for tests."
	^ default ifNil: [ default := self forWorkspace: SmallChatPharoWorkspace default ]
]

{ #category : 'instance creation' }
SmallChatLMCapabilityCatalog class >> forWorkspace: aWorkspace [
	"Build a catalog scoped to one workspace. Only capabilities whose
	 supportedWorkspaces lists aWorkspace kind appear in toolSchemas --
	 a TS chat does not see eval/debug/vcs.status, a Pharo chat does."
	^ self new workspace: aWorkspace; yourself
]

{ #category : 'accessing' }
SmallChatLMCapabilityCatalog class >> reset [
	default := nil
]

{ #category : 'accessing' }
SmallChatLMCapabilityCatalog >> toolSchemas [
	"One OpenAI-function schema per registered production capability whose
	 supportedWorkspaces lists this catalog's workspace kind AND whose
	 isLmFacing returns true. Test fixtures (#isTestFixture true) and
	 transport-only capabilities (workspace.list / attach-ts / detach) are
	 filtered out so they never reach the LM. Returned as Array (STONJSON
	 requires Array, not OrderedCollection)."
	| kind |
	kind := workspace kind.
	^ (((SmallChatCapabilityRegistry default allCapabilities
		reject: [ :cap | cap isTestFixture or: [ cap isLmFacing not ] ])
		select: [ :cap | cap supportedWorkspaces includes: kind ])
		collect: [ :cap |
			cap schema
				asOpenAIFunctionSchemaName: cap capabilityName
				description: cap description ]) asArray
]

{ #category : 'accessing' }
SmallChatLMCapabilityCatalog >> workspace [
	^ workspace
]

{ #category : 'accessing' }
SmallChatLMCapabilityCatalog >> workspace: aWorkspace [
	workspace := aWorkspace
]
