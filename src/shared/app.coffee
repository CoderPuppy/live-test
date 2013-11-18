{EventEmitter} = require 'events'
muxy           = require 'muxy'

# TODO: This is the storage model right now
module.exports = class App extends EventEmitter
	constructor: ->
		@models = {}

	register: (name, sb) ->
		@models[name] = sb
		@

	createStream: ->
		mx = muxy()

		for name, sb of @models
			sbStream = sb.createStream()
			sbStream.pipe(mx.open(name)).pipe(sbStream)

		mx
