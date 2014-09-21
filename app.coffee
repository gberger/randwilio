_ = require("underscore")
express = require("express")
bodyParser = require("body-parser")
twilio = require("twilio")

app = express()
app.use bodyParser.json()
app.use bodyParser.urlencoded()

client = new twilio.RestClient(process.env.TWILIO_ACC, process.env.TWILIO_TOKEN)
send = (to, body) ->
	num = to.number || to
	console.log "> [#{num}] #{body}"
	client.messages.create
		to: num
		from: process.env.TWILIO_NUMBER
		body: body
	, (error, message) ->
		console.log error.message  if error


strWait = ">> Be patient, we're still looking for a stranger for you to chat with. Commands: #stop"
strStarted = ">> You're now chatting to a stranger on randwilio. Commands: #stop #next"
strSearching = ">> We're searching for a stranger for you to chat on randwilio. Commands: #stop"
strYouStopped = ">> You stopped chatting to this stranger. Text anything to chat to someone else."
strPartnerStopped = ">> The stranger stopped chatting. Text anything to chat to someone else."
strStoppedSearching = ">> We stopped searching for a stranger for you to chat. Text anything to chat to someone."

QUEUE = []
USERS = []

class User
	constructor: (number) ->
		@number = number
		@partner = null
		@pastMatches = []
		USERS.push(this)

findOrInitialize = (number) ->
	_.findWhere(USERS, {number: number}) || new User(number)

insertIntoQueue = (user) ->
	for other in QUEUE
		if other not in user.pastMatches
			user.partner = other
			other.partner = user
			send(user.number, strStarted)
			send(other.number, strStarted)
			user.pastMatches.push(other)
			other.pastMatches.push(user)
			removeFromQueue(other)
			return false
	QUEUE.push(user)
	return true

removeFromQueue = (user) ->
	QUEUE = _.filter QUEUE, (x) -> x != user

app.post "/sms", (req, res) ->
	from = req.body.From
	msg = req.body.Body
	msgl = msg.toLowerCase()

	console.log "< [#{from}] #{msg}"

	user = findOrInitialize(from)

	if user.partner
		if msgl.indexOf("#stop") == 0
			send user.number, strYouStopped
			send user.partner.number, strPartnerStopped
			user.partner.partner = null
			user.partner = null
		else if msgl.indexOf("#next") == 0
			send user.partner.number, strPartnerStopped
			user.partner.partner = null
			user.partner = null
			if insertIntoQueue(user)
				send user.number, strSearching
		else
			send user.partner.number, "[??] " + msg
	else
		if msgl.indexOf("#stop") == 0
			removeFromQueue(user)
			send user.number, strStoppedSearching
		else
			if user in QUEUE
				send user.number, strWait
			else if insertIntoQueue(user)
				send user.number, strSearching

app.listen 3000
