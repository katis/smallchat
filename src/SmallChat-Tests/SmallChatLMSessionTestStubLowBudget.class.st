Class {
	#name : 'SmallChatLMSessionTestStubLowBudget',
	#superclass : 'SmallChatLMSession',
	#category : 'SmallChat-Tests',
	#package : 'SmallChat-Tests'
}

{ #category : 'tool dispatch' }
SmallChatLMSessionTestStubLowBudget >> maxToolIterations [
  "Force the tool-call budget to 0 so a single tool-calling reply trips
   the synthetic budget-exhausted path. Used by the
   testSendUserInputBudgetExhaustedSetsErrored fixture."
  ^ 0
]
