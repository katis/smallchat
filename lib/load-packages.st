"Headless loader for smallchat.

Reads SMALLCHAT_REPO from the environment (set by install.sh) to locate
the local clone, registers it as an Iceberg repository pointing at the
src/ subdirectory, and Metacello-loads BaselineOfSmallChat. The load
must succeed before --save or the image ends up without the package.

Invoked by install.sh as:
    SMALLCHAT_REPO=/abs/path/to/clone \\
        pharo --headless Pharo.image st --quit --save lib/load-packages.st

The Iceberg registration is wrapped in on:do: because the scripting
selectors differ slightly across Pharo / Iceberg versions; if it fails,
Metacello still loads the code so the image is usable. You can then
register the clone manually via Iceberg's 'Import from existing clone'."

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

"1. Register local clone with Iceberg."
[
	(Smalltalk globals includesKey: #IceRepository) ifTrue: [
		| existing repoClass creatorClass |
		repoClass := Smalltalk globals at: #IceRepository.
		existing := repoClass registry
			detect: [ :r | [ r location = repoDir ] on: Error do: [ :_ | false ] ]
			ifNone: [ nil ].
		existing
			ifNil: [
				creatorClass := Smalltalk globals at: #IceRepositoryCreator.
				(creatorClass new
					location: repoDir;
					subdirectory: 'src';
					createRepository) register.
				Transcript show: 'Registered Iceberg repository at '; show: repoDir fullName; cr ]
			ifNotNil: [
				Transcript show: 'Iceberg repository already registered.'; cr ] ]
		ifFalse: [
			Transcript show: 'Iceberg not in image; skipping repo registration.'; cr ]
] on: Error do: [ :e |
	Transcript
		show: 'Iceberg registration failed (';
		show: e messageText;
		show: '); continuing with Metacello load.';
		cr ].

"2. Load BaselineOfSmallChat from the local tonel tree."
tonelUrl := 'tonel://', (repoDir / 'src') fullName.
Transcript show: 'Loading BaselineOfSmallChat from '; show: tonelUrl; cr.
Metacello new
	baseline: 'SmallChat';
	repository: tonelUrl;
	load.

"3. Strip the persistent Welcome window so GUI launches don't beachball
 on the first click. Safe to do headlessly."
SystemWindow allSubInstancesDo: [ :w |
	w title = 'Welcome' ifTrue: [ w delete ] ].
(Smalltalk globals includesKey: #StWelcomeBrowser) ifTrue: [
	(Smalltalk globals at: #StWelcomeBrowser) allInstancesDo: [ :b |
		[ b window ifNotNil: [ :win | win close ] ]
			on: Error do: [ :_ | ] ] ].

Transcript show: 'smallchat baseline loaded.'; cr.
