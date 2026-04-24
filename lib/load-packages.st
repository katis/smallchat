"Dev-image loader for smallchat.

Reads SMALLCHAT_REPO from the environment (set by install.sh) and
Metacello-loads BaselineOfSmallChat from the on-disk Tonel tree at
<repo>/src. The load must succeed before --save or the image ends up
without the package.

Invoked by install.sh as:
    SMALLCHAT_REPO=/abs/path/to/clone \\
        pharo --headless Pharo.image st --quit --save lib/load-packages.st

Two modes, distinguished by SMALLCHAT_MCP_MODE:

- Unset (default): verifier image. Loads only the `default` group
  (SmallChat + SmallChat-Tests). No MCP, no Iceberg. Used by
  `just test` and `just lint`, both of which wipe and re-materialise
  from the seed before running. The image is disposable.

- '1': dev image. Loads the `dev` group (adds SmallChat-MCP), wires
  the MCP server classes into SessionManager so they auto-start on
  every image launch, and runs lib/iceberg-setup.st to register the
  smallchat repo with Iceberg. Long-lived; talked to by Claude Code
  via ./bin/smallchat-mcp."

| repoPath repoDir tonelUrl mcpMode |

repoPath := OSEnvironment current
	at: 'SMALLCHAT_REPO'
	ifAbsent: [
		Transcript show: 'SMALLCHAT_REPO not set; aborting.'; cr.
		^ self ].
repoDir := repoPath asFileReference.
repoDir exists ifFalse: [
	Transcript show: 'Repo path does not exist: '; show: repoPath; cr.
	^ self ].
(repoDir / 'src') exists ifFalse: [
	Transcript show: 'No src/ under repo path: '; show: repoPath; cr.
	^ self ].

mcpMode := (OSEnvironment current at: 'SMALLCHAT_MCP_MODE' ifAbsent: [ '0' ]) = '1'.

Transcript show: 'smallchat repo: '; show: repoDir fullName; cr.
Transcript show: 'mode: '; show: (mcpMode ifTrue: [ 'dev (MCP + Iceberg)' ] ifFalse: [ 'verifier (default)' ]); cr.

tonelUrl := 'tonel://', (repoDir / 'src') fullName.
Transcript show: 'Loading BaselineOfSmallChat from '; show: tonelUrl; cr.
Metacello new
	baseline: 'SmallChat';
	repository: tonelUrl;
	load: (mcpMode ifTrue: [ 'dev' ] ifFalse: [ 'default' ]).

"Strip the persistent Welcome window so GUI launches don't beachball
 on the first click. Safe to do headlessly."
SystemWindow allSubInstancesDo: [ :w |
	w title = 'Welcome' ifTrue: [ w delete ] ].
(Smalltalk globals includesKey: #StWelcomeBrowser) ifTrue: [
	(Smalltalk globals at: #StWelcomeBrowser) allInstancesDo: [ :b |
		[ b window ifNotNil: [ :win | win close ] ]
			on: Error do: [ :_ | ] ] ].

mcpMode ifTrue: [
	Transcript show: 'Wiring SmallChat-MCP into SessionManager.'; cr.
	SessionManager default
		registerUserClassNamed: 'SmallChatMCPServer';
		registerUserClassNamed: 'SmallChatMCPTcpServer'.

	Transcript show: 'Running lib/iceberg-setup.st.'; cr.
	OpalCompiler new evaluate:
		(repoDir / 'lib' / 'iceberg-setup.st') readStream upToEnd.

	SmallChatTreeSitterHealth reportOn: Transcript ].

Transcript show: 'smallchat baseline loaded.'; cr.
