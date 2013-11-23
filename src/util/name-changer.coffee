reconnect = require 'reconnect'
ldata     = require 'live-data'
base      = require '../shared/base'
net       = require 'net'
fs        = require 'fs'

# log = fs.createWriteStream 'log'

reconnect((stream) ->
# stream = net.connect 3010
	# console.log 'opened stream'
	# stream.pipe log
	stream.pipe(base.createStream()).pipe(stream)

	m = base.messages

	filter = (key, raw) ->
		parts = raw.split(':')


		if parts.length <= 1 || parts.length > 2 || parts[0].length > 25 || parts[1].length <= 1 || parts[1].length > 75
			process.nextTick -> m._unset(key)
			return

		if (match = /^[^?!.]+([?!.]+)$/.exec(parts[0])) && (match[1].replace(/[^?]/g, '').length > 1 || match[1].replace(/[^!]/g, '').length > 1 || match[1].replace(/[^.]/g, '').length > 1)
			process.nextTick -> m._unset(key)

	m.on 'insert', (index, msg, key) ->
		filter(key, msg.get())
		msg.on 'update', filter.bind(this, key)
).connect(3010, '127.0.0.1')