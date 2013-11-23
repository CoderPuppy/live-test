ecstatic = require 'ecstatic'
connect  = require 'connect'
http     = require 'http'
path     = require 'path'
shoe     = require 'shoe'
base     = require '../shared/base'
net      = require 'net'

mw = connect()
sock = shoe()

mw.use ecstatic root: path.join(__dirname, '../../public')

sock.on 'connection', (stream) ->
	stream.pipe(base.createStream()).pipe(stream)

server = http.createServer(mw)
sock.install server, '/stream.shoe'
server.listen 3000, -> console.log "app is listening on localhost:#{server.address().port}"

netServer = net.createServer (stream) ->
	stream.on 'error', (err) ->
		console.log('error: ', err)
	
	stream.pipe(base.createStream()).pipe(stream)
netServer.listen 3010, -> console.log "net is listening on localhost:#{netServer.address().port}"