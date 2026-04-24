"Iceberg bring-up for the dev image.

Invoked from lib/load-packages.st when SMALLCHAT_MCP_MODE=1 is set.
Skipped entirely on the verifier path so that image stays Iceberg-free.

Three things to do:

1. Install the Package>>isLoaded shim. Iceberg's IceCommit calls
   #isLoaded on every Package it iterates, but Pharo 13's renamed
   Package class doesn't define it. Without the shim, workingCopyDiff
   and modifiedPackages both raise DoesNotUnderstand.

2. Register the smallchat git working tree with Iceberg:
   - location: <repo>
   - subdirectory: 'src'
   - ensureProjectFile so IceBasicProject is bound to the source dir.
     The on-disk .project file (committed earlier) already has the
     same bytes, so the registration produces no diff.

3. Attach the loaded SmallChat-* packages to the working copy so
   Iceberg tracks them for write-back / commit.

Idempotent: a repo at the right location is reused if already
registered (e.g. across save-and-continue snapshots)."

| pkgClass iceRepo creatorClass orgClass org location existing repo packageNames |

"1. Package>>isLoaded shim."
pkgClass := Smalltalk globals at: #Package.
(pkgClass canUnderstand: #isLoaded) ifFalse: [
	pkgClass
		compile: 'isLoaded
	"Shim for Iceberg compatibility under Pharo 13. A Package known to
	the organizer is by definition loaded."
	^ true'
		classified: 'shims-iceberg-pharo13'.
	Transcript show: 'iceberg-setup: installed Package>>isLoaded shim'; cr ].

"2. Register the repo (idempotent)."
iceRepo := Smalltalk globals at: #IceRepository.
creatorClass := Smalltalk globals at: #IceRepositoryCreator.
location := (OSEnvironment current at: 'SMALLCHAT_REPO') asFileReference.

existing := iceRepo registry
	detect: [ :r | ([ r location ] on: Error do: [ :_ | nil ]) = location ]
	ifNone: [ nil ].

repo := existing ifNil: [
	| r |
	r := creatorClass new
		location: location;
		subdirectory: 'src';
		ensureProjectFile;
		addLocalRepository.
	iceRepo registerRepository: r.
	r name: 'smallchat'.
	Transcript show: 'iceberg-setup: registered smallchat at '; show: location fullName; cr.
	r ].
existing ifNotNil: [
	Transcript show: 'iceberg-setup: smallchat already registered at '; show: location fullName; cr ].

"3. Attach packages to the working copy. Then mark all packages clean,
 since the in-image state was just loaded by Metacello from the same
 Tonel files that HEAD points to -- by construction they match. Without
 this, every attached package shows as 'all-additions' relative to
 Iceberg's empty initial diff index."
orgClass := Smalltalk globals at: #PackageOrganizer.
org := orgClass default.
packageNames := #('BaselineOfSmallChat' 'SmallChat' 'SmallChat-Tests' 'SmallChat-MCP' 'SmallChat-LSP' 'SmallChat-LSP-Tests').
packageNames do: [ :pkgName |
	(org packageNamed: pkgName ifAbsent: [ nil ]) ifNotNil: [ :pkg |
		[ repo workingCopy basicAddPackage: pkg ] on: Error do: [ :_ | ] ] ].

[ repo workingCopy refreshPackages ]
	on: Error do: [ :e |
		Transcript show: 'iceberg-setup: refreshPackages failed: '; show: e messageText; cr ].

Transcript show: 'iceberg-setup: done'; cr.
