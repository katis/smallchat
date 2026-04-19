"Headless lint runner for smallchat.

Runs Pharo's Critiques engine (ReCriticEngine) over every package whose
name starts with 'SmallChat', prints each critique, and exits non-zero
if any are found so `just lint` surfaces them in CI / pre-commit.

Invoked by justfile as:
    pharo --headless Pharo.image eval --save=false lib/lint.st

Note on exit status: `Smalltalk exitFailure` returns exit code 1, which
is what the justfile recipe relies on. A clean run prints 'lint: ok'
and exits 0."

| packages total |
packages := PackageOrganizer default packages
	select: [ :p | p name beginsWith: 'SmallChat' ].
packages ifEmpty: [
	Transcript show: 'lint: no SmallChat-* packages loaded — did the baseline load?'; cr.
	Smalltalk exitFailure ].

total := 0.
packages do: [ :pkg |
	| critiques |
	critiques := ReCriticEngine critiquesOf: pkg.
	critiques do: [ :c |
		total := total + 1.
		Transcript
			show: pkg name; show: ': ';
			show: (c rule name ifNil: [ c rule class name ]); show: ' — ';
			show: c description; cr ] ].

total = 0
	ifTrue: [
		Transcript show: 'lint: ok ('; show: packages size printString; show: ' packages)'; cr ]
	ifFalse: [
		Transcript show: 'lint: '; show: total printString; show: ' critique(s)'; cr.
		Smalltalk exitFailure ].
