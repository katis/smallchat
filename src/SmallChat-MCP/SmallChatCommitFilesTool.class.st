Class {
	#name : 'SmallChatCommitFilesTool',
	#superclass : 'SmallChatTool',
	#instVars : [
		'gitRunner',
		'resyncer'
	],
	#category : 'SmallChat-MCP',
	#package : 'SmallChat-MCP'
}

{ #category : 'accessing - metadata' }
SmallChatCommitFilesTool class >> description [
	^ 'Commit hand-edited files on disk (non-Iceberg-managed: CLAUDE.md, justfile, bin/*, lib/*.st, baselines, .mcp.json, etc.) via shell git, then re-anchor the in-image Iceberg working copy to the new HEAD. Without this, the next `commit` via Iceberg raises IceWorkingCopyDesyncronized because the in-image referenceCommit is stale. Do NOT use for Pharo source under src/SmallChat*; those go through `evaluate` + `commit`.'
]

{ #category : 'accessing - metadata' }
SmallChatCommitFilesTool class >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'paths' put: (Dictionary new
				at: 'type' put: 'array';
				at: 'items' put: (Dictionary new at: 'type' put: 'string'; yourself);
				at: 'description' put: 'Repo-relative file paths to stage. Passed to `git add -- <paths>` verbatim, so deletions/renames work if git sees them.';
				yourself);
			at: 'message' put: (Dictionary new
				at: 'type' put: 'string';
				at: 'description' put: 'Commit message. Required.';
				yourself);
			yourself);
		at: 'required' put: #('paths' 'message');
		yourself
]

{ #category : 'accessing - metadata' }
SmallChatCommitFilesTool class >> toolName [
	^ 'commit_files'
]

{ #category : 'execution' }
SmallChatCommitFilesTool >> errorResult: aString [
	^ STONJSON toString: (Dictionary new
		at: 'error' put: aString;
		yourself)
]

{ #category : 'accessing' }
SmallChatCommitFilesTool >> gitRunner: aBlock [
	gitRunner := aBlock
]

{ #category : 'accessing' }
SmallChatCommitFilesTool >> resyncer: aBlock [
	resyncer := aBlock
]

{ #category : 'execution' }
SmallChatCommitFilesTool >> run: args [
	| paths message commitId |
	paths := args at: 'paths' ifAbsent: [ ^ self errorResult: 'paths is required' ].
	message := args at: 'message' ifAbsent: [ ^ self errorResult: 'message is required' ].
	(paths isCollection and: [ paths isString not ]) ifFalse: [
		^ self errorResult: 'paths must be a non-empty array of strings' ].
	paths isEmpty ifTrue: [
		^ self errorResult: 'paths must be a non-empty array of strings' ].
	(paths allSatisfy: [ :p | p isString and: [ p isEmpty not ] ]) ifFalse: [
		^ self errorResult: 'paths must be a non-empty array of strings' ].
	(message isString and: [ message isEmpty not ]) ifFalse: [
		^ self errorResult: 'message must be a non-empty string' ].
	gitRunner value: { 'add'. '--' } , paths asArray.
	gitRunner value: { 'commit'. '-m'. message }.
	commitId := resyncer value.
	^ STONJSON toString: (Dictionary new
		at: 'commitId' put: commitId;
		at: 'message' put: message;
		yourself)
]
