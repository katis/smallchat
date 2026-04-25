Class {
	#name : 'SmallChatFamixStonRoundTripTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Tests',
	#package : 'SmallChat-Famix-Tests'
}

{ #category : 'tests' }
SmallChatFamixStonRoundTripTest >> testProjectModulesAndClassesRoundTrip [
	"Build 1 Project + 2 Modules + 2 Classes (5 entities) with names and
	 source anchors. STON to-from must preserve count, classes, names."
	| anchor entities str recovered |
	anchor := SmallChatFamixSourceAnchor
		fileUri: 'file:///abs/x.tsx' startByte: 0 endByte: 1.
	entities := OrderedCollection new
		add: ((SmallChatFamixProject new) name: 'demo'; yourself);
		add: ((SmallChatFamixModule new) name: 'a.tsx'; sourceAnchor: anchor; yourself);
		add: ((SmallChatFamixModule new) name: 'b.tsx'; sourceAnchor: anchor; yourself);
		add: ((SmallChatFamixClass new) name: 'A'; sourceAnchor: anchor; yourself);
		add: ((SmallChatFamixClass new) name: 'B'; sourceAnchor: anchor; yourself);
		yourself.
	str := STON toString: entities.
	recovered := STON fromString: str.
	self assert: recovered size equals: 5.
	self assert: (recovered first isKindOf: SmallChatFamixProject).
	self assert: recovered first name equals: 'demo'.
	self assert: (recovered second isKindOf: SmallChatFamixModule).
	self assert: ((recovered collect: [ :e | e name ]) asArray)
		equals: #('demo' 'a.tsx' 'b.tsx' 'A' 'B').
	self assert: recovered last sourceAnchor startByte equals: 0
]
