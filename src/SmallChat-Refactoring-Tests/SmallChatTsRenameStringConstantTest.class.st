Class {
	#name : 'SmallChatTsRenameStringConstantTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'tests' }
SmallChatTsRenameStringConstantTest >> testFileNameFilterRestrictsScope [
  "fileNameFilter is a Pharo regex (RxMatcher search:) tested against
   each candidate URI. Only matching files are processed; the unfiltered
   src file is left byte-for-byte unchanged."
  | fs srcFile testFile applier cmd outcome srcOriginal testOriginal testExpected |
  fs := FileSystem memory.
  (fs / '/proj') ensureCreateDirectory.
  srcFile := fs / '/proj/foo.tsx'.
  testFile := fs / '/proj/foo.test.tsx'.
  srcOriginal := 'const x = "isDocEmpty";'.
  testOriginal := 'describe("isDocEmpty", () => {});'.
  testExpected := 'describe("isDocumentEmpty", () => {});'.
  srcFile writeStreamDo: [ :s | s nextPutAll: srcOriginal ].
  testFile writeStreamDo: [ :s | s nextPutAll: testOriginal ].
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  cmd := SmallChatTsRenameStringConstantCommand new
    applier: applier;
    rootUri: 'file:///proj';
    oldText: 'isDocEmpty';
    newText: 'isDocumentEmpty';
    fileNameFilter: '\.test\.tsx?$';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: (srcFile readStreamDo: [ :s | s upToEnd ]) equals: srcOriginal.
  self assert: (testFile readStreamDo: [ :s | s upToEnd ]) equals: testExpected
]

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
SmallChatTsRenameStringConstantTest >> testNilFileNameFilterRewritesEveryDiscoveredFile [
  "Without a fileNameFilter, every discovered file under rootUri is
   processed. Mirrors testFileNameFilterRestrictsScope but omits the
   filter -- both files end up rewritten."
  | fs srcFile testFile applier cmd outcome srcExpected testExpected |
  fs := FileSystem memory.
  (fs / '/proj') ensureCreateDirectory.
  srcFile := fs / '/proj/foo.tsx'.
  testFile := fs / '/proj/foo.test.tsx'.
  srcFile writeStreamDo: [ :s | s nextPutAll: 'const x = "isDocEmpty";' ].
  testFile writeStreamDo: [ :s | s nextPutAll: 'describe("isDocEmpty", () => {});' ].
  srcExpected := 'const x = "isDocumentEmpty";'.
  testExpected := 'describe("isDocumentEmpty", () => {});'.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  cmd := SmallChatTsRenameStringConstantCommand new
    applier: applier;
    rootUri: 'file:///proj';
    oldText: 'isDocEmpty';
    newText: 'isDocumentEmpty';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: (srcFile readStreamDo: [ :s | s upToEnd ]) equals: srcExpected.
  self assert: (testFile readStreamDo: [ :s | s upToEnd ]) equals: testExpected
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

{ #category : 'tests' }
SmallChatTsRenameStringConstantTest >> testRewritesLiteralTemplateString [
  "Literal-only template strings (no ${...}) are rewritten the same as
   `string` literals. Interpolated templates are skipped: even if the
   identifier inside ${...} matches oldText, only string fragments are
   rewritten -- backticks-with-substitution stay untouched."
  | fs file uri applier cmd outcome originalText expectedText |
  fs := FileSystem memory.
  file := fs / '/foo.tsx'.
  originalText := 'const a = `isDocEmpty`;
const b = `pre ${isDocEmpty} post`;'.
  expectedText := 'const a = `isDocumentEmpty`;
const b = `pre ${isDocEmpty} post`;'.
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
