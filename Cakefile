childProcess = require 'child_process'

build = (watch, cb) ->
	run 'node', ['node_modules/coffee-script/bin/coffee', (if watch then '-cw' else '-c'), '-o', 'lib', 'src'], cb
	browserifyArgs = ['node_modules/browserify/bin/cmd.js', 'lib/client/client.js', '-o', 'public/bundle.js', '-d']
	if watch
		browserifyArgs = ['node_modules/nodemon/nodemon.js', '--watch', 'lib/client', '--watch', 'node_modules', '--watch', 'lib/shared'].concat(browserifyArgs)
	run 'node', browserifyArgs

run = (exec, args, cb) ->
	proc = childProcess.spawn exec, args
	proc.stdout.on 'data', (buffer) -> console.log buffer.toString()
	proc.stderr.on 'data', (buffer) -> console.log buffer.toString()
	proc.on 'exit', (status) ->
		process.exit(1) if status != 0
		cb() if typeof cb is 'function'

task 'build', 'build everything', -> build false
task 'build:watch', 'keep everything built', -> build true

task 'npm:install', 'install all the packages', -> run 'node', ['/usr/local/bin/npm', 'install']
task 'npm:install:watch', 'install all the packages', -> run 'node', ['node_modules/nodemon/nodemon.js', '-e', 'json', '/usr/local/bin/npm', 'install']

task 'server', 'run the server', ->
	run 'node', ['node_modules/forever/bin/forever',
	             '-o', 'server.log', '-e', 'server.log', '--spinSleepTime', '0',
	             'lib/server/server.js']

task 'server:dev', 'run the server', ->
	console.log '\x1B[32mRunning server in development\x1B[0m'
	run 'node', ['node_modules/nodemon/nodemon.js', '--watch', 'lib', '-e', 'js', '-q', '--exitcrash', 'lib/server/server.js']