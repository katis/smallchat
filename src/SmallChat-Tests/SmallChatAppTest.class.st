"
Smoke test for the SmallChat baseline. Exists primarily so `just test`
has something real to run; replace with genuine coverage as features land.
"
Class {
	#name : #SmallChatAppTest,
	#superclass : #TestCase,
	#category : #'SmallChat-Tests'
}

{ #category : #tests }
SmallChatAppTest >> testVersionIsDeclared [
	self
		assert: SmallChatApp version isString;
		deny: SmallChatApp version isEmpty
]
