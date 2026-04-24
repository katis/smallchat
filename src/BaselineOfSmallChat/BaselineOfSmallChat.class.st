Class {
	#name : 'BaselineOfSmallChat',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfSmallChat',
	#package : 'BaselineOfSmallChat'
}

{ #category : 'baselines' }
BaselineOfSmallChat >> baseline: spec [
	<baseline>
	spec for: #common do: [
		spec
			baseline: 'OSSubprocess' with: [
				spec repository: 'github://pharo-contributions/OSSubprocess:01754067b0352fc45623ed1f3c5f8c159556465a/repository' ];
			baseline: 'TreeSitter' with: [
				spec
					loads: #('default' 'typescript' 'css');
					repository: 'github://Evref-BL/Pharo-Tree-Sitter:e621baf6cf9d33289289098f04e92326d3f6716c/src' ];
			baseline: 'Famix' with: [
				spec
					loads: #('Basic');
					repository: 'github://moosetechnology/Famix:e841ebfd10bb59a6b94e0d31e759486bf3cea911/src' ].
		spec
			package: 'SmallChat';
			package: 'SmallChat-MCP'       with: [ spec requires: #('SmallChat') ];
			package: 'SmallChat-LM'        with: [ spec requires: #('SmallChat' 'SmallChat-MCP') ];
			package: 'SmallChat-LSP'       with: [ spec requires: #('SmallChat') ];
			package: 'SmallChat-Tests'     with: [ spec requires: #('SmallChat' 'SmallChat-LM' 'SmallChat-MCP') ];
			package: 'SmallChat-LSP-Tests' with: [ spec requires: #('SmallChat-LSP' 'SmallChat-Tests') ].
		spec
			group: 'default' with: #('SmallChat' 'SmallChat-LM' 'SmallChat-MCP' 'SmallChat-LSP' 'SmallChat-Tests' 'SmallChat-LSP-Tests');
			group: 'core'    with: #('SmallChat' 'SmallChat-LM');
			group: 'tests'   with: #('SmallChat-Tests' 'SmallChat-LSP-Tests');
			group: 'mcp'     with: #('SmallChat' 'SmallChat-LM' 'SmallChat-MCP');
			group: 'dev'     with: #('SmallChat' 'SmallChat-LM' 'SmallChat-Tests' 'SmallChat-MCP' 'SmallChat-LSP' 'SmallChat-LSP-Tests' 'OSSubprocess' 'TreeSitter' 'Famix') ]
]
