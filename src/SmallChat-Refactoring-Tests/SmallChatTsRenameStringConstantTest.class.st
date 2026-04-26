Class {
	#name : 'SmallChatTsRenameStringConstantTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Refactoring-Tests',
	#package : 'SmallChat-Refactoring-Tests'
}

{ #category : 'tests' }
SmallChatTsRenameStringConstantTest >> testEmptyMatchSetReturnsErrorReason [
  "When no string fragment matches oldText, apply returns a failed
   outcome with errorReason. Files on disk stay unchanged."
  | fs file applier cmd outcome originalText |
  fs := FileSystem memory.
  file := fs / '/foo.tsx'.
  originalText := 'const x = "other";'.
  file writeStreamDo: [ :s | s nextPutAll: originalText ].
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  cmd := SmallChatTsRenameStringConstantCommand new
    applier: applier;
    rootUri: 'file:///';
    oldText: 'isDocEmpty';
    newText: 'isDocumentEmpty';
    yourself.
  outcome := cmd apply.
  self deny: outcome isSuccess.
  self assert: (outcome errorReason includesSubstring: 'isDocEmpty').
  self assert: (file readStreamDo: [ :s | s upToEnd ]) equals: originalText
]

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
SmallChatTsRenameStringConstantTest >> testIgnoresFilesOutsideDefaultExtensions [
  "discoverFileUris keeps only .ts/.tsx/.js/.jsx files. A .css and .md
   under the same root containing the literal text are left untouched."
  | fs cssFile mdFile tsFile applier cmd outcome cssOriginal mdOriginal tsExpected |
  fs := FileSystem memory.
  (fs / '/proj') ensureCreateDirectory.
  cssFile := fs / '/proj/styles.css'.
  mdFile := fs / '/proj/notes.md'.
  tsFile := fs / '/proj/foo.tsx'.
  cssOriginal := '.btn { content: "isDocEmpty" }'.
  mdOriginal := 'Use isDocEmpty for empty checks.'.
  cssFile writeStreamDo: [ :s | s nextPutAll: cssOriginal ].
  mdFile writeStreamDo: [ :s | s nextPutAll: mdOriginal ].
  tsFile writeStreamDo: [ :s | s nextPutAll: 'const x = "isDocEmpty";' ].
  tsExpected := 'const x = "isDocumentEmpty";'.
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  cmd := SmallChatTsRenameStringConstantCommand new
    applier: applier;
    rootUri: 'file:///proj';
    oldText: 'isDocEmpty';
    newText: 'isDocumentEmpty';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self assert: (cssFile readStreamDo: [ :s | s upToEnd ]) equals: cssOriginal.
  self assert: (mdFile readStreamDo: [ :s | s upToEnd ]) equals: mdOriginal.
  self assert: (tsFile readStreamDo: [ :s | s upToEnd ]) equals: tsExpected
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

{ #category : 'tests' }
SmallChatTsRenameStringConstantTest >> testRollbackRestoresAllFilesByteForByte [
  "After a multi-file rename, rollback: restores every touched file
   byte-for-byte from the rollbackToken (delegated to the applier)."
  | fs fileA fileB applier cmd outcome originalA originalB |
  fs := FileSystem memory.
  (fs / '/proj') ensureCreateDirectory.
  fileA := fs / '/proj/a.tsx'.
  fileB := fs / '/proj/b.tsx'.
  originalA := 'const x = "isDocEmpty";'.
  originalB := 'describe("isDocEmpty", () => {});'.
  fileA writeStreamDo: [ :s | s nextPutAll: originalA ].
  fileB writeStreamDo: [ :s | s nextPutAll: originalB ].
  applier := SmallChatWorkspaceEditApplier new fileSystem: fs; yourself.
  cmd := SmallChatTsRenameStringConstantCommand new
    applier: applier;
    rootUri: 'file:///proj';
    oldText: 'isDocEmpty';
    newText: 'isDocumentEmpty';
    yourself.
  outcome := cmd apply.
  self assert: outcome isSuccess.
  self deny: (fileA readStreamDo: [ :s | s upToEnd ]) equals: originalA.
  self deny: (fileB readStreamDo: [ :s | s upToEnd ]) equals: originalB.
  cmd rollback: outcome rollbackToken.
  self assert: (fileA readStreamDo: [ :s | s upToEnd ]) equals: originalA.
  self assert: (fileB readStreamDo: [ :s | s upToEnd ]) equals: originalB
]
