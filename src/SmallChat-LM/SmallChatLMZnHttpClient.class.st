"
Thin adapter around ZnClient: POST a JSON string body to a URL, return
the response body string. Exists so SmallChatLMCompletionsClient can
depend on a small injectable seam (#post:to:) rather than the full
ZnClient surface -- tests inject a stub with the same two-method
protocol.
"
Class {
	#name : 'SmallChatLMZnHttpClient',
	#superclass : 'Object',
	#category : 'SmallChat-LM',
	#package : 'SmallChat-LM'
}

{ #category : 'api' }
SmallChatLMZnHttpClient >> post: aJsonString to: aUrl withHeaders: aHeadersDict [
	| client |
	client := ZnClient new
		url: aUrl;
		entity: (ZnEntity with: aJsonString type: ZnMimeType applicationJson);
		yourself.
	aHeadersDict keysAndValuesDo: [ :k :v | client headerAt: k put: v ].
	^ client post; contents
]

{ #category : 'api' }
SmallChatLMZnHttpClient >> post: aJsonString to: aUrl withHeaders: aHeadersDict onChunk: aChunkBlock [
    "Streaming POST. Sends aJsonString as application/json, opens the response in
     streaming mode, and reads SSE-style 'data: {...}' frames from the body line
     by line. Each non-sentinel data line is parsed via STONJSON and forwarded to
     aChunkBlock; the OpenAI '[DONE]' sentinel ends the stream. Closes the client
     in an ensure block so a raise from aChunkBlock still frees the socket.

     OpenAI/oMLX put one JSON object per 'data:' line, so we don't reassemble
     multi-line frames per the SSE spec -- if a server starts splitting payloads
     across lines, this will need a per-frame buffer."
    | client text payload |
    client := ZnClient new
        url: aUrl;
        entity: (ZnEntity with: aJsonString type: ZnMimeType applicationJson);
        streaming: true;
        yourself.
    aHeadersDict keysAndValuesDo: [ :k :v | client headerAt: k put: v ].
    [ client post.
      text := ZnCharacterReadStream on: client response entity readStream.
      [ text atEnd ] whileFalse: [
          | line |
          line := text nextLine.
          (line beginsWith: 'data: ') ifTrue: [
              payload := line copyFrom: 7 to: line size.
              payload = '[DONE]'
                  ifTrue: [ ^ self ]
                  ifFalse: [ aChunkBlock value: (STONJSON fromString: payload) ] ] ] ]
        ensure: [ client close ]
]
