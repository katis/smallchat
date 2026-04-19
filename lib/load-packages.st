"Dev-image loader for smallchat.

Reads SMALLCHAT_REPO from the environment (set by install.sh) and
Metacello-loads BaselineOfSmallChat from the on-disk Tonel tree at
<repo>/src. The load must succeed before --save or the image ends up
without the package.

Invoked by install.sh as:
    SMALLCHAT_REPO=/abs/path/to/clone \\
        pharo --headless Pharo.image st --quit --save lib/load-packages.st

This script produces a *development* image used only for running tests
and the linter. It is disposable: `just test` wipes it and re-runs this
loader on every invocation, so anything in the image that didn't come
from src/ is lost.

Iceberg is deliberately not touched here. In-image source control is a
feature of the shipped (distributable) smallchat image, and is
configured by a separate build step — not by this loader."

| repoPath repoDir tonelUrl |

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

Transcript show: 'smallchat repo: '; show: repoDir fullName; cr.

"1. Load BaselineOfSmallChat from the local tonel tree."
tonelUrl := 'tonel://', (repoDir / 'src') fullName.
Transcript show: 'Loading BaselineOfSmallChat from '; show: tonelUrl; cr.
Metacello new
	baseline: 'SmallChat';
	repository: tonelUrl;
	load.

"2. Strip the persistent Welcome window so GUI launches don't beachball
 on the first click. Safe to do headlessly."
SystemWindow allSubInstancesDo: [ :w |
	w title = 'Welcome' ifTrue: [ w delete ] ].
(Smalltalk globals includesKey: #StWelcomeBrowser) ifTrue: [
	(Smalltalk globals at: #StWelcomeBrowser) allInstancesDo: [ :b |
		[ b window ifNotNil: [ :win | win close ] ]
			on: Error do: [ :_ | ] ] ].

Transcript show: 'smallchat baseline loaded.'; cr.
