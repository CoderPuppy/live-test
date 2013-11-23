reconnect = require 'reconnect'
ldata     = require 'live-data'
# repl    = require 'coffee-script/lib/coffee-script/repl'
repl      = require 'repl'
base      = require '../shared/base'

reconnect((stream) ->
	stream.pipe(base.createStream()).pipe(stream)
).connect(3010)

r = repl.start
	useGlobal: true

r.context.ldata = ldata
r.context.base  = base

r.on 'exit', -> process.exit()