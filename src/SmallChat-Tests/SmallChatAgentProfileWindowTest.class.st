Class {
	#name : 'SmallChatAgentProfileWindowTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tests' }
SmallChatAgentProfileWindowTest >> testWindowBuildsAndShowsDefault [
	"A new window has all four editor presenters wired up, and its profile
	 list reflects the registry -- so a fresh image opens to the seeded
	 Default agent ready for inspection."
	| win listed |
	SmallChatAgentProfile reset.
	win := SmallChatAgentProfileWindow new.
	self assert: win profileList notNil.
	self assert: win nameInput notNil.
	self assert: win modelDropList notNil.
	self assert: win promptText notNil.
	listed := win profileList items collect: [ :p | p name ].
	self assert: (listed includes: 'Default')
]
