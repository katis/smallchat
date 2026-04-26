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
			package: 'SmallChat-Nav'              with: [ spec requires: #() ];
			package: 'SmallChat-Workspace'        with: [ spec requires: #('SmallChat' 'SmallChat-LSP') ];
			package: 'SmallChat-Capability'       with: [ spec requires: #('SmallChat' 'SmallChat-Workspace') ];
			package: 'SmallChat-MCP'              with: [ spec requires: #('SmallChat' 'SmallChat-Capability') ];
			package: 'SmallChat-LM'               with: [ spec requires: #('SmallChat' 'SmallChat-Capability') ];
			package: 'SmallChat-LSP'              with: [ spec requires: #('SmallChat') ];
			package: 'SmallChat-TreeSitter'       with: [ spec requires: #('SmallChat') ];
			package: 'SmallChat-Famix'            with: [ spec requires: #('SmallChat' 'SmallChat-TreeSitter') ];
			package: 'SmallChat-Famix-Importer'   with: [ spec requires: #('SmallChat' 'SmallChat-LSP' 'SmallChat-TreeSitter' 'SmallChat-Famix') ];
			package: 'SmallChat-Refactoring'      with: [ spec requires: #('SmallChat' 'SmallChat-TreeSitter' 'SmallChat-Famix') ];
			package: 'SmallChat-Tests'            with: [ spec requires: #('SmallChat' 'SmallChat-LM' 'SmallChat-MCP') ];
			package: 'SmallChat-Capability-Tests' with: [ spec requires: #('SmallChat-Capability' 'SmallChat-Tests') ];
			package: 'SmallChat-Workspace-Tests'  with: [ spec requires: #('SmallChat-Workspace' 'SmallChat-Tests') ];
			package: 'SmallChat-NavTests'         with: [ spec requires: #('SmallChat-Nav' 'SmallChat-Tests') ];
			package: 'SmallChat-LSP-Tests'        with: [ spec requires: #('SmallChat-LSP' 'SmallChat-Tests') ];
			package: 'SmallChat-TreeSitter-Tests' with: [ spec requires: #('SmallChat-TreeSitter' 'SmallChat-Tests') ];
			package: 'SmallChat-Famix-Tests'      with: [ spec requires: #('SmallChat-Famix' 'SmallChat-Tests') ];
			package: 'SmallChat-Famix-Importer-Tests' with: [ spec requires: #('SmallChat-Famix-Importer' 'SmallChat-Tests') ];
			package: 'SmallChat-Refactoring-Tests' with: [ spec requires: #('SmallChat-Refactoring' 'SmallChat-Tests') ].
		spec
			"All bindings (TreeSitter, Famix) load in default so just test exercises
			 them for real. Leaving a binding out lets isAvailable-guarded tests
			 skip silently in CI; the M3 phase hit a NULL-handle regression that
			 hid for weeks because walker tests skipped under the verifier image."
			group: 'default' with: #('SmallChat' 'SmallChat-Nav' 'SmallChat-Workspace' 'SmallChat-Capability' 'SmallChat-LM' 'SmallChat-MCP' 'SmallChat-LSP' 'SmallChat-TreeSitter' 'SmallChat-Famix' 'SmallChat-Famix-Importer' 'SmallChat-Refactoring' 'SmallChat-Tests' 'SmallChat-Capability-Tests' 'SmallChat-Workspace-Tests' 'SmallChat-NavTests' 'SmallChat-LSP-Tests' 'SmallChat-TreeSitter-Tests' 'SmallChat-Famix-Tests' 'SmallChat-Famix-Importer-Tests' 'SmallChat-Refactoring-Tests' 'TreeSitter' 'Famix');
			group: 'core'    with: #('SmallChat' 'SmallChat-Workspace' 'SmallChat-Capability' 'SmallChat-LM');
			group: 'tests'   with: #('SmallChat-Tests' 'SmallChat-Capability-Tests' 'SmallChat-Workspace-Tests' 'SmallChat-NavTests' 'SmallChat-LSP-Tests' 'SmallChat-TreeSitter-Tests' 'SmallChat-Famix-Tests' 'SmallChat-Famix-Importer-Tests' 'SmallChat-Refactoring-Tests');
			group: 'mcp'     with: #('SmallChat' 'SmallChat-Workspace' 'SmallChat-Capability' 'SmallChat-LM' 'SmallChat-MCP');
			group: 'dev'     with: #('SmallChat' 'SmallChat-Nav' 'SmallChat-Workspace' 'SmallChat-Capability' 'SmallChat-LM' 'SmallChat-Tests' 'SmallChat-Capability-Tests' 'SmallChat-Workspace-Tests' 'SmallChat-NavTests' 'SmallChat-MCP' 'SmallChat-LSP' 'SmallChat-LSP-Tests' 'SmallChat-TreeSitter' 'SmallChat-TreeSitter-Tests' 'SmallChat-Famix' 'SmallChat-Famix-Tests' 'SmallChat-Famix-Importer' 'SmallChat-Famix-Importer-Tests' 'SmallChat-Refactoring' 'SmallChat-Refactoring-Tests' 'OSSubprocess' 'TreeSitter' 'Famix') ]
]
