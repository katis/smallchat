Class {
	#name : 'SmallChatTsRenameStringConstantTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'tests' }
SmallChatTsRenameStringConstantTest >> testLeavesIdentifierOccurrencesUntouched [
  "Identifier occurrences with the same name are NOT rewritten -- only
   string-fragment matches are. Regression guard against the walker
   accidentally returning identifier text as a fragment."
  | fs file uri applier cmd outcome originalText expectedText |
  fs := FileSystem memory.
  file := fs / '/foo.test.tsx'.
  originalText := 'function isDocEmpty() { return true; }
describe("isDocEmpty", () => isDocEmpty());'.
  expectedText := 'function isDocEmpty() { return true; }
describe("isDocumentEmpty", () => isDocEmpty());'.
  file writeStreamDo: [ :s | s nextPutAll: originalText ].
  uri := 'file://' , file fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  cmd := SmallChatTsRenameStringConstantCommand new
    applier: applier;
    rootUri: 'file:///';
    oldText: 'isDocEmpty';
    newText: 'isDocumentEmpty';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: expectedText
]

{ #category : 'tests' }
SmallChatTsRenameStringConstantTest >> testRenamesExactStringMatchInSingleFile [
  "Plain string literal whose content equals oldText is rewritten;
   quotes stay, only the fragment byte range is replaced. apply walks
   the rootUri directory through the applier-injected FileSystem."
  | fs file uri applier cmd outcome originalText expectedText |
  fs := FileSystem memory.
  file := fs / '/foo.test.tsx'.
  originalText := 'describe("isDocEmpty", () => {});'.
  expectedText := 'describe("isDocumentEmpty", () => {});'.
  file writeStreamDo: [ :s | s nextPutAll: originalText ].
  uri := 'file://' , file fullName.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  cmd := SmallChatTsRenameStringConstantCommand new
    applier: applier;
    rootUri: 'file:///';
    oldText: 'isDocEmpty';
    newText: 'isDocumentEmpty';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: expectedText
]
