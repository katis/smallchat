Class {
	#name : 'SmallChatCapability',
	#superclass : 'Object',
	#category : 'SmallChat-Capability',
	#package : 'SmallChat-Capability'
}

{ #category : 'metadata' }
SmallChatCapability class >> capabilityName [
	"Agent-visible identifier (string). Concrete subclasses MUST override
	 with their prefixed name (e.g. 'vcs.status'). Used by the registry
	 to look up capabilities and by transports to render schemas."
	^ self subclassResponsibility
]

{ #category : 'metadata' }
SmallChatCapability class >> description [
	"Free-text human-readable summary. Single short paragraph."
	^ self subclassResponsibility
]

{ #category : 'testing' }
SmallChatCapability class >> isAbstract [
	"True for the abstract base. Subclasses are concrete unless they
	 redefine this. Reflective discovery uses this to filter."
	^ self == SmallChatCapability
]

{ #category : 'metadata' }
SmallChatCapability class >> isTestFixture [
	"Override to true on test-only subclasses so transports can filter them
	 out of agent-facing surfaces (tools/list, LM tool catalog). Production
	 capabilities leave this at false."
	^ false
]

{ #category : 'execution' }
SmallChatCapability class >> run: aCapabilityCall [
	"Receive a SmallChatCapabilityCall and return a SmallChatCapabilityResult.
	 Capabilities are stateless: dispatch happens on the class, not an instance."
	^ self subclassResponsibility
]

{ #category : 'metadata' }
SmallChatCapability class >> schema [
	"A SmallChatCapabilitySchema describing the input arguments. Use
	 SmallChatCapabilitySchema empty for capabilities that take no args."
	^ self subclassResponsibility
]

{ #category : 'metadata' }
SmallChatCapability class >> supportedWorkspaces [
	"Workspace kinds this capability supports. Default is #(#pharo)
	 -- the original assumption when every capability ran against the
	 live image. TS-only or workspace-neutral capabilities override.
	 Used by the registry to filter dispatch at the boundary."
	^ #(#pharo)
]
