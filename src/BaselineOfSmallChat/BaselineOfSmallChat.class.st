Class {
	#name : #BaselineOfSmallChat,
	#superclass : #BaselineOf,
	#category : #BaselineOfSmallChat
}

{ #category : #baselines }
BaselineOfSmallChat >> baseline: spec [
	<baseline>
	spec for: #common do: [
		spec package: 'SmallChat' ]
]
