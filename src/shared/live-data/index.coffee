{EventEmitter} = require 'events'
Scuttlebucket  = require 'scuttlebucket'
# DuplexStream = require 'duplex-stream'
Scuttlebutt    = require 'scuttlebutt'
{filter}       = require 'scuttlebutt/util'
through        = require 'through'
between        = require 'between'
RArray         = require 'r-array'
RValue         = require 'r-value'
REdit          = require 'r-edit'
util           = require 'util'
hat            = require 'hat'
ss             = require 'stream-serializer'

# limiter = (delay = 100) ->
# 	times = {}
# 	stackback = null
# 	try
# 		throw new Error('catch this')
# 	catch e
# 		stackback = e
# 	stream = through (data) ->
# 		console.log 'got data in limiter:', data
# 		# debugger
# 		key = JSON.stringify data[0]
# 		now = new Date().getTime()
# 		if times[key]? and now - times[key] < delay
# 			console.log 'rejecting'
# 			return
# 		setTimeout (-> times[key] = undefined), delay
# 		times[key] = now
# 		@queue(data)
# 	stream.errback = stackback
# 	stream

order = (a, b) ->
	# timestamp, then source
	between.strord(a[1], b[1]) || between.strord(a[2], b[2])

dutyOfSubclass = (name) -> -> throw new Error("#{@constructor.name}.#{name} must be implemented")

# name should be the lowercased name of the class
class Base extends Scuttlebutt
	@types: {}
	@register: (type) ->
		@types[type.name.toLowerCase()] = type

	@create: (name, args...) ->
		new @types[name](args...)

	pipe: (dest) ->
		@createReadStream().pipe(dest.createWriteStream())
		dest

	map: (fn, args...) ->
		newLive = new @constructor
		# mapper = newLive.mapper.bind(newLive, fn, args...)
		mapper = (update) -> newLive.mapper(update, fn, args...)

		@createReadStream().pipe(ss.json(through((update) ->
			res = mapper(update)
			console.log res
			@queue res
		))).pipe(newLive.createWriteStream())

		newLive

	# What args to pass to the constructor when initially replicating it
	creationArgs: dutyOfSubclass 'creationArgs'
	# Map the creation args
	# @mapCreationArgs: dutyOfSubclass '@mapCreationArgs'

	# TODO: Document this
	mapper: dutyOfSubclass 'mapper'

	# Scuttlebutt Stuff
	applyUpdate: dutyOfSubclass 'applyUpdate'
	history: dutyOfSubclass 'history'

class Array extends Base
	constructor: (vals...) ->
		super()
		@_sb   = new RArray
		@_db   = {}
		@_hist = {}
		@_rack = hat.rack()

		@length = new Value(0)

		@_updateBuffer = {}
		@_sbKeys       = {}
		@_dbKeys       = {}

		@_sb.on 'update', (rawUpdate) =>
			update = {}

			for sbKey, key of rawUpdate
				update[key] = @_db[key]

			@emit 'update', update

			for sbKey, key of rawUpdate
				if key? and update[key]? # Update or insert
					if @_updateBuffer[key]?
						@emit 'update', @_sb.indexOfKey(sbKey), update[key], key, sbKey
					else
						@emit 'insert', @_sb.indexOfKey(sbKey), update[key], key, sbKey

						@length.set(@length.get() + 1)

					@_updateBuffer[key] = update[key]
				else # Delete
					key = @_dbKeys[sbKey]

					if @_updateBuffer[key]?
						@emit 'remove', @_sb.indexOfKey(sbKey), @_updateBuffer[key], key, sbKey
						delete @_updateBuffer[key]
						delete @_sbKeys[key]
						delete @_dbKeys[sbKey]
						process.nextTick(((key) -> delete @_db[key]).bind(@, key))

						@length.set(@length.get() - 1)
					else
						# I think this occurs when it's replaying and it tries to delete an element that doesn't exist
						# console.log("the update is null and the buffer is null", update, rawUpdate, sbKey, key, @)
						# throw new Error('the update is null and the buffer is null')

			for sbKey, key of rawUpdate
				if key?
					@_sbKeys[key] = sbKey
					@_dbKeys[sbKey] = key
				else
					delete @_dbKeys[sbKey]

			return

		@_sb.on '_update', (update) =>
			console.log 'Array._sb updated'
			@emit '_update', [ [ 'a', update[0] ], update[1], update[2] ]

		@push val for val in vals

	creationArgs: -> [] # @_sb.toJSON().map (key) => @_db[key]
	@mapCreationArgs: (fn, args) -> [] # args

	# Internal Functions
	_genId: -> @_rack()
	_register: (val, key = @_genId(), update = true) ->
		if update
			@localUpdate [ 'd', key, val.constructor.name.toLowerCase(), val.creationArgs() ]
		@_db[key] = val
		# I don't know of a way to remove this
		val.on '_update', (update) =>
			if @_db[key] == val
				@emit '_update', [ [ 'c', key, update[0] ], update[1], update[2] ]
		key
	_setIndex: (index, key) ->
		@_sb.set @_sb.keys[index], key

	push: (val) ->
		key = @_register val
		@_sb.push key
		@

	unshift: (val) ->
		key = @_register val
		@_sb.unshift key
		@

	# TODO: This shouldn't be this complicated
	get: (index) ->
		@_db[@_sb.get @_sb.keys[index]]

	pop: ->
		key = @_sb.pop()
		@_db[key]

	shift: ->
		key = @_sb.shift()
		@_db[key]

	forEach: (fn) ->
		for i in [0 .. @length.get() - 1]
			fn(@get(i), i)
	each: (fn) -> @forEach(fn)

	# TODO: Figure out how to implement indexOf

	mapper: (update, fn, subArgs = []) ->
		if util.isArray(update)
			data = update[0]

			switch data[0]
				when 'c'
					childUpdate = [ data[2], update[1], update[2] ]

					childUpdate = @_db[data[1]].mapper(fn, subArgs..., childUpdate)

					[ [ 'c', data[1], childUpdate[0] ], childUpdate[1], childUpdate[2] ]
				when 'd'
					[ [ 'd', data[1], data[2], Base.types[data[2]].mapCreationArgs(fn, data[3]) ], update[1], update[2] ]
				else return update
		else
			return update

	# Scuttlebutt Implementation
	history: (sources) ->
		hist = @_sb.history(sources).map (update) ->
			[ [ 'a', update[0] ], update[1], update[2] ]

		for key, update of @_hist
			if !~hist.indexOf(update) && filter(update, sources)
				hist.push update

		for key, val of @_db
			hist = hist.concat val.history(sources).map((update) -> [ [ 'c', key, update[0] ], update[1], update[2] ])

		hist.sort order

	applyUpdate: (update) ->
		data = update[0]

		switch data[0]
			# Array
			when 'a' then @_sb.applyUpdate([ data[1], update[1], update[2] ])
			# DB
			when 'd'
				@_hist[data[1]] = update

				if !@_db[data[1]]?
					@_register Base.create(data[2], data[3]...), data[1], false

				@emit '_register', data[1], @_db[data[1]]

				true
			# Child updates
			when 'c'
				if @_db[data[1]]?
					@_db[data[1]]._update([ data[2], update[1], update[2] ])

Base.Array = Array
Base.register Array

class Value extends Base
	constructor: (defaultVal, force = false) ->
		super()
		@_sb = new RValue
		@_sb.on 'update', (data) => @emit 'update', data
		@_sb.on '_update', (update) => @emit '_update', [ update[0], update[1], @id ]

		# TODO: Fix this
		if defaultVal? # and force
			# @defaultVal = null
			@set defaultVal

	creationArgs: -> [@get()]
	@mapCreationArgs: (fn, args) -> [ fn(args[0]) ]

	set: (newValue) ->
		if @get() != newValue
			@_sb.set newValue
		@

	get: ->
		if @_sb._history.length then @_sb.get() else @defaultVal

	mapper: (update, fn) -> [ fn(update[0]), update[1], update[2] ]

	# TODO: Unmap
	# TODO: Make this just a filter in a pipe
	# map: (fn) ->
	# 	val = new @constructor

	# 	update = =>
	# 		cb = val.set.bind(val)
	# 		res = fn(@get(), cb)

	# 		# TODO: Add support for promises
	# 		if res?
	# 			cb(res)

	# 	update()

	# 	@on 'update', update

	# 	val

	history: (sources) -> @_sb.history(sources)
	applyUpdate: (update) -> @_sb.applyUpdate(update)

	# createStream: ->
	# 	output = limiter()
	# 	input  = limiter()
	# 	input.pipe(@_sb.createStream()).pipe(output)
	# 	stream = new DuplexStream(output, input)
	# 	stream.resume()
	# 	stream
	# createReadStream: -> @_sb.createReadStream().pipe(limiter())
	# createWriteStream: ->
	# 	input = limiter()
	# 	input.pipe(@_sb.createWriteStream())
	# 	input

	# pipe: (val) ->
	# 	@on 'update', (d) -> val.set(d)
	# 	val.set(@get())

Base.Value = Value
Base.register Value

# # TODO: This doesn't work
# class Text extends Value
# 	constructor: ->
# 		@sb = new REdit
# 		@sb.on 'update', => @emit 'update', @get()
# 		@sb.on 'update', =>
# 			newValue = @sb.text()
# 			# console.log('newValue:', newValue)
# 			# if /^testing/.test(newValue) and newValue != 'testing'
# 			# 	if window?
# 			# 		throw new Error('why?')
# 			# 	else
# 			# 		console.trace('why?')

# 	set: (newValue) ->
# 		console.log('set text to ', newValue)
# 		@sb.text newValue
# 		@

# 	get: -> @sb.text()

# Base.Text = Text
# Base.register Text

module.exports = Base