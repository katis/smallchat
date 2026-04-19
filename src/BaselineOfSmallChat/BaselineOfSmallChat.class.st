Class {
	#name : #BaselineOfSmallChat,
	#superclass : #BaselineOf,
	#category : #BaselineOfSmallChat
}

{ #category : #baselines }
BaselineOfSmallChat >> baseline: spec [
	<baseline>
	spec for: #common do: [
		spec
			package: 'SmallChat';
			package: 'SmallChat-Tests' with: [ spec requires: #('SmallChat') ].
		spec
			group: 'default' with: #('SmallChat' 'SmallChat-Tests');
			group: 'core' with: #('SmallChat');
			group: 'tests' with: #('SmallChat-Tests') ]
]
