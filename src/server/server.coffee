ecstatic = require 'ecstatic'
connect  = require 'connect'
http     = require 'http'
path     = require 'path'
shoe     = require 'shoe'
base     = require '../shared/base'

mw = connect()
sock = shoe()

mw.use ecstatic root: path.join(__dirname, '../../public')

sock.on 'connection', (stream) ->
	stream.pipe(base.createStream()).pipe(stream)

server = http.createServer(mw)
sock.install server, '/stream.shoe'
server.listen(3001, -> console.log('app is listening on localhost:3000'))