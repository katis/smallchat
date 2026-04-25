Class {
	#name : 'SmallChatFamixImporterJsxTest',
	#superclass : 'TestCase',
	#category : 'SmallChat-Famix-Importer-Tests',
	#package : 'SmallChat-Famix-Importer-Tests'
}

{ #category : 'helpers' }
SmallChatFamixImporterJsxTest >> newImporterOn: aModel [
  ^ SmallChatFamixImporter new
    model: aModel
    client: nil
    parser: SmallChatTSParser new
    walker: SmallChatTSNodeWalker new
]

{ #category : 'tests' }
SmallChatFamixImporterJsxTest >> testConstArrowBlockBodyReturningJsxEmitsJsxComponent [
  "Block-bodied arrow: `const Foo = () => { return <div/> }`."
  | model importer text uri |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'const Foo = () => { return <div/> }'.
  uri := 'file:///t/Foo.tsx'.
  importer populateJsxComponentsFromText: text intoUri: uri.
  self assert: (model allWithType: SmallChatFamixJSXComponent) size equals: 1.
  self assert: (model allWithType: SmallChatFamixJSXComponent) first name equals: 'Foo'
]

{ #category : 'tests' }
SmallChatFamixImporterJsxTest >> testConstArrowReturningJsxEmitsJsxComponent [
  "Concise-body arrow: `const Foo = () => <div/>` -- arrow_function's last
   named child is JSX directly."
  | model importer text uri comp |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'const Foo = () => <div/>'.
  uri := 'file:///t/Foo.tsx'.
  importer populateJsxComponentsFromText: text intoUri: uri.
  self assert: (model allWithType: SmallChatFamixJSXComponent) size equals: 1.
  comp := (model allWithType: SmallChatFamixJSXComponent) first.
  self assert: comp name equals: 'Foo'.
  self assert: comp sourceAnchor startByte equals: 0.
  self assert: comp sourceAnchor endByte equals: text size
]

{ #category : 'tests' }
SmallChatFamixImporterJsxTest >> testConstArrowReturningNonJsxIsSkipped [
  "`const x = () => 42` -- no JSX, no JSXComponent."
  | model importer |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  importer populateJsxComponentsFromText: 'const x = () => 42' intoUri: 'file:///t/x.ts'.
  self assert: (model allWithType: SmallChatFamixJSXComponent) size equals: 0
]

{ #category : 'tests' }
SmallChatFamixImporterJsxTest >> testFunctionDeclarationReturningJsxEmitsJsxComponent [
  "A top-level function whose body returns a JSX element / self-closing
   element / fragment is detected as a JSXComponent. Name comes from the
   function's identifier; sourceAnchor covers the whole declaration."
  | model importer text uri components comp |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'function Foo() { return <div/> }'.
  uri := 'file:///t/Foo.tsx'.
  importer populateJsxComponentsFromText: text intoUri: uri.
  components := model allWithType: SmallChatFamixJSXComponent.
  self assert: components size equals: 1.
  comp := components first.
  self assert: comp name equals: 'Foo'.
  self assert: comp sourceAnchor fileUri equals: uri.
  self assert: comp sourceAnchor startByte equals: 0.
  self assert: comp sourceAnchor endByte equals: text size
]

{ #category : 'tests' }
SmallChatFamixImporterJsxTest >> testFunctionReturningJsxFragmentEmitsJsxComponent [
  "Returning a JSX fragment <>...</> counts as JSX too -- not just elements."
  | model importer |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  importer
    populateJsxComponentsFromText: 'function Wrap(){ return <><span/></> }'
    intoUri: 'file:///t/Wrap.tsx'.
  self assert: (model allWithType: SmallChatFamixJSXComponent) size equals: 1.
  self assert: (model allWithType: SmallChatFamixJSXComponent) first name equals: 'Wrap'
]

{ #category : 'tests' }
SmallChatFamixImporterJsxTest >> testNonJsxFunctionDoesNotEmitJsxComponent [
  "Plain function declaration whose body has no JSX-typed return must not
   produce a JSXComponent. Locks in the heuristic against future widening."
  | model importer |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  importer
    populateJsxComponentsFromText: 'function add(x, y) { return x + y }'
    intoUri: 'file:///t/Math.ts'.
  self assert: (model allWithType: SmallChatFamixJSXComponent) size equals: 0
]

{ #category : 'tests' }
SmallChatFamixImporterJsxTest >> testTanstackPairArrowEmitsJsxComponent [
  "TanStack-style nested component definition: `({ component: () => <X/> })`.
   The arrow lives under call_expression > arguments > object > pair >
   arrow_function. Emit one JSXComponent named after the property key
   (`component`); anchor covers the arrow_function's byte range (precision
   over uniformity -- the surrounding variable_declarator can have many
   pairs)."
  | model importer text uri comp |
  model := SmallChatFamixModel new.
  importer := self newImporterOn: model.
  text := 'export const Route = createFileRoute("/_authed")({ component: () => <Outlet /> })'.
  uri := 'file:///t/route._authed.tsx'.
  importer populateJsxComponentsFromText: text intoUri: uri.
  self assert: (model allWithType: SmallChatFamixJSXComponent) size equals: 1.
  comp := (model allWithType: SmallChatFamixJSXComponent) first.
  self assert: comp name equals: 'component'.
  self assert: comp sourceAnchor fileUri equals: uri.
  "arrow_function byte range from S6 AST: 62..78"
  self assert: comp sourceAnchor startByte equals: 62.
  self assert: comp sourceAnchor endByte equals: 78
]
