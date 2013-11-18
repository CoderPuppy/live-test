through = require 'through'
ldata   = require '../shared/live-data'
muxy    = require 'muxy'
App     = require '../shared/app'

exports.client = window? and document?

app = new App
exports.app = app

val = new ldata.Value
val.on 'update', (val) ->
	console.log 'val updated, new value:', val
	# if val == ''
	# 	throw new Error('bad')
app.register 'val', val

exports.val = val

exports.name = name = new ldata.Value
name.on 'update', (val) -> console.log 'name updated, new value:', val
app.register 'name', name

if exports.client
	exports.message = message = new ldata.Value
else
	exports.message = message = name.map (name) -> "Hello, #{name}!"

app.register 'message', message

exports.messages = messages = new ldata.Array
app.register 'messages', messages

exports.createStream = -> app.createStream()