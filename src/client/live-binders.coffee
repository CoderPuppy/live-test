ldata = require 'live-data'

exports.textContent = (el) ->
	val = new ldata.Value
	val.on 'update', (d) -> el.textContent = d
	val

exports.innerHTML = (el) ->
	val = new ldata.Value
	val.on 'update', (d) -> el.innerHTML = d
	val

exports.value = (el) ->
	val = new ldata.Value
	
	applyDom = (d) ->
		if typeof d == 'string' and d.length > 0 and el.value != d
			el.value = d

	# applyDom val.get()
	val.on 'update', applyDom

	if el.value
		val.set el.value

	applyModel = ->
		val.set el.value
	el.addEventListener('input', applyModel)
	el.addEventListener('keyup', applyModel)
	val

exports.array = (parent, fn) ->
	arr = new ldata.Array

	elements = {}

	arr.on 'insert', (index, val, key, sbKey) ->
		el = elements[key] = fn(val)
		parent.appendChild el

		arr.emit 'dom:insert', index, el, val, key, sbKey

	arr.on 'remove', (index, val, key) ->
		parent.removeChild elements[key]
		delete elements[key]

	arr