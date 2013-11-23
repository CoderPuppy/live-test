require 'shoe' # So reconnect will detect shoe
reconnect = require 'reconnect'
domready  = require 'domready'
binders   = require '../client/live-binders'
ldata     = require 'live-data'
base      = require '../shared/base'

window.val = base.val
window.app = base.app

window.m = base.messages

window.ldata = ldata

username = new ldata.Value 'No One'

domready ->
	messagesBinding = null

	(->
		container = document.createElement 'div'
		document.body.appendChild container
		container.style.overflow = 'scroll'
		container.style.position = 'relative'
		container.style.height   = '500px'
		container.style.border   = '1px solid black'
		container.id = 'messages'

		# messages = document.createElement 'ul'
		# container.appendChild messages
		messagesBinding = binders.array(container, (val) ->
			el = document.createElement 'div'
			val.map((str) -> str.replace(/\t/g, '    ').replace(/[ ]/g, '&nbsp;')).pipe binders.innerHTML(el)
			el
		)
		base.messages.pipe(messagesBinding)

		container.scrollTop = container.scrollHeight
		setInterval(->
		# messagesBinding.on 'dom:insert', ->
			if container.scrollHeight - container.scrollTop <= 505
				container.scrollTop = container.scrollHeight
		, 10)
	)()

	usernameField = document.createElement 'input'
	username.pipe(binders.value usernameField).pipe username
	document.body.appendChild usernameField

	(->
		form = document.createElement 'form'
		form.addEventListener('submit', (e) ->
			e.stopPropagation()
			e.preventDefault()
			e.returnValue = false

			sendingMessage = msg.value
			base.messages.push username.map (username) ->
				"#{username}: #{sendingMessage}" # new ldata.Value(msg.value)
			msg.value = ''

			return false
		)
		document.body.appendChild form

		form.style.display = 'inline'

		msg = document.createElement 'input'
		form.appendChild msg

		clear = document.createElement 'button'
		clear.textContent = 'Clear Chat'
		clear.addEventListener 'click', (e) ->
			# base.messages.each ->
			messagesBinding.each ->
				@pop()
		document.body.appendChild clear
	)()

	label = document.createElement('div')
	document.body.appendChild label
	base.val.pipe binders.innerHTML label

	input = document.createElement('input')
	document.body.appendChild input
	base.val.pipe(binders.value input).pipe(base.val)

	name = document.createElement('input')
	document.body.appendChild name
	base.name.pipe(binders.value name).pipe(base.name)

	message = document.createElement('span')
	document.body.appendChild message
	base.message.pipe(binders.textContent message)

reconnect((stream) ->
	stream.pipe(base.createStream()).pipe(stream)

	# window.writer = base.writer
).connect('/stream.shoe')