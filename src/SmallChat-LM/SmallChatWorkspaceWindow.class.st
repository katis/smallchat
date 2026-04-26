"
Spec2 window bound to one attached SmallChatTsWorkspace. The world-menu launcher pops a directory picker, attaches a TS workspace via SmallChatTsWorkspace>>attachAt:name:, mounts it on the SmallChatCapabilityRegistry, and opens this window. Closing the window detaches the workspace (registry unmount + ws shutdown).

Holds a chatPlaceholder presenter as the drop-in slot for a future workspace-scoped chat panel; the panel will be parameterised by a SmallChatLMSession whose tool dispatch stamps this workspace onto each call, and a SmallChatLMCapabilityCatalog filtered to the workspace kind.

Note: today the LSP launcher in SmallChatTsWorkspace defaults to nil, so attach is pure object construction and runs on the UI process. When real tsgo wiring lands, attach becomes blocking I/O and must move to a fork with status fed back via UIManager default defer:.
"
Class {
	#name : 'SmallChatWorkspaceWindow',
	#superclass : 'SpPresenter',
	#instVars : [
		'workspace'
	],
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> workspace [
	^ workspace
]

{ #category : 'accessing' }
SmallChatWorkspaceWindow >> workspace: aWorkspace [
	workspace := aWorkspace
]
