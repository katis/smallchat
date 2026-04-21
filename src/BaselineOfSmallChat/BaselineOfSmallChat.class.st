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
			package: 'SmallChat-LM'    with: [ spec requires: #('SmallChat') ];
			package: 'SmallChat-MCP'   with: [ spec requires: #('SmallChat') ];
			package: 'SmallChat-Tests' with: [ spec requires: #('SmallChat' 'SmallChat-LM' 'SmallChat-MCP') ].
		spec
			group: 'default' with: #('SmallChat' 'SmallChat-LM' 'SmallChat-MCP' 'SmallChat-Tests');
			group: 'core'    with: #('SmallChat' 'SmallChat-LM');
			group: 'tests'   with: #('SmallChat-Tests');
			group: 'mcp'     with: #('SmallChat' 'SmallChat-LM' 'SmallChat-MCP');
			group: 'dev'     with: #('SmallChat' 'SmallChat-LM' 'SmallChat-Tests' 'SmallChat-MCP') ]
]
