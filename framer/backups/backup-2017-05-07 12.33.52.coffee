# Import file "pinning-0" (sizes and positions are scaled 1:2)
sketch = Framer.Importer.load("imported/pinning-0@2x")


Framer.Device.orientation = 90

# Helper functions
rect = (x, y, width, height) -> 
	{x:x, y:y, width:width, height:height}

point = (x,y) -> {x:x, y:y}

rectIntersect = (rectA, rectB) ->
	if (rectA.x < rectB.x + rectB.width &&
		rectA.x + rectA.width > rectB.x &&
		rectA.y < rectB.y + rectB.height &&
		rectA.height + rectA.y > rectB.y)
			return true
	return false
	
pointInRect = (pt, rect) ->
	if (pt.x > rect.x && pt.x < rect.x + rect.width &&
		pt.y > rect.y && pt.y < rect.y + rect.height)
			return true
	return false

layerToRect = (layer) ->
	rect(layer.x, layer.y, layer.width, layer.height)

coords = (pt) -> Canvas.convertPointToScreen(pt)

# Stage objects
stage		= sketch.stage
key 		= sketch.key
mapMarker 	= sketch.mapMarker
lockHitRect	= sketch.lockHitRect
lock 		= sketch.pinnedThread
lockHint	= sketch.dragHint
lockConfirm = sketch.dragConfirmation
tray 		= sketch.tray
matte		= sketch.matte
modal		= sketch.pinIntro

app =
	state: ""
	emitter: new Framer.EventEmitter
	key:
		startX: key.x
		startY: key.y
		isDragging: false
		isPressed: false
		ptTouchStart: {x:null, y:null}
		ptTouchMove: {x:null, y:null}
		longpressTimer: 0
		longpressHoldThreshold: 500
	

# State definitions
	
tray.states.closed =
	animationOptions:
		curve: 'ease-out'
		time: 0.25
	y: -tray.height
tray.states.opened =
	animationOptions:
		curve: 'bezier-curve(.9,0,.1,1)'
		time: 0.4
	y: 0

matte.states.hidden =
	opacity: 0
matte.states.visible =
	opacity: 1

mapMarker.originY = 1
mapMarker.animationOptions =
	curve: 'ease-out'
	time: 0.08
mapMarker.states.hidden =
	opacity: 0
	scale: 0.25
mapMarker.states.visible =
	opacity: 1
	scale: 1
	
key.states.isNotPickedUp =
	animationOptions:
		curve: 'ease-out'
		time: 0.25
	opacity: 1
	x: app.key.startX
	y: app.key.startY
	scale: 0.25
key.states.hidden =
	animationOptions:
		curve: 'ease-out'
		time: 0.1
	opacity: 0
	
key.states.isPickedUp =
	animationOptions:
		curve: "spring(800,15,0)"
	opacity: 1
	scale: 1

lock.states.animationOptions =
	curve: "spring(800, 15, 10)"
lock.states.hoverOn = 
	scale: 1.1
lock.states.hoverOff =
	scale: 1

lockConfirm.animationOptions =
	curve: 'ease-out'
	time: 0.1
lockConfirm.states.off = 
	opacity: 0
	scale: 0.25
lockConfirm.states.on =
	opacity: 1
	scale: 1

lockHint.animationOptions =
	curve: 'ease-out'
	time: 0.1
lockHint.states.on =
	opacity: 1
lockHint.states.off =
	opacity: 0

modalStartY = modal.y
modal.states.visible =
	opacity: 1
	y: modalStartY
	animationOptions:
		curve: "spring(400, 30, 10)"
modal.states.hidden =
	opacity: 0
	y: modalStartY + 100
	animationOptions:
		curve: 'ease-out'
		time: 0.1

# Application event handling
app.emitter.on "uichange", (event) ->
	if app.state != event.name
		print "from: " + app.state + " to: " + event.name
	else
		# nothing to do
		return
	
	switch event.name
		when "reset"		
			tray.stateSwitch("closed")
			matte.stateSwitch("hidden")
			key.stateSwitch("hidden")
			mapMarker.stateSwitch("visible")
			lockConfirm.stateSwitch "off"
			lockHint.stateSwitch "on"
			modal.animate "hidden"
			
		when "keyIsPickedUp"
			tray.animate("opened")
			key.animate("isPickedUp")
			matte.animate("visible")
			mapMarker.animate("hidden")
		
		when "keyWillDrop"
			tray.animate("closed")
			matte.animate("hidden")
			lockHint.animate "on"
			key.states.switch "isNotPickedUp"
			Utils.delay 0.25, ->
				key.states.switch "hidden"
				mapMarker.animate("visible")
		
		when "keyWillUnlock"
			lockConfirm.animate "on"
			Utils.delay 0.25, ->
				lock.animate "hoverOff"
				mapMarker.animate "visible"
			lockHint.animate "off"
			key.stateSwitch "isNotPickedUp"
			key.stateSwitch "hidden"
			Utils.delay 0.5, ->
				tray.animate "closed"
			Utils.delay 1, ->
				app.emitter.emit "uichange", {name:"showModal"}
		
		when "showModal"
			matte.animate "visible"
			modal.animate "visible"
		
		when "hideModal"
			matte.animate "hidden"
			modal.animate "hidden"
			Utils.delay 1, ->
				app.emitter.emit "uichange", {name: "reset"}
			
	app.state = event.name


# Resets drag flags. If the key is dropped, tell the state manager
killDrag = (willDrop) ->
	print "Drag Killed"
	app.key.isDragging = false
	app.key.isPressed = false
	app.key.ptTouchStart = {x:null, y:null}
	clearTimeout(app.key.longpressTimer)
		
	

key.draggable.enabled = true

# The stage is responsible for responding to user
# interaction with keys and locks
stage.onTouchStart ->
	e = Events.touchEvent(event)
	ptTouchStart = coords(point(e.clientX, e.clientY))
	
	if !pointInRect(app.key.ptTouchMove, layerToRect(key))
		return
	else
		app.key.ptTouchStart = ptTouchStart
	
	print "TouchStart", app.key.ptTouchStart
	app.key.isPressed = true
	app.key.longpressTimer = setTimeout ( ->
		if (app.key.isPressed &&
			app.key.ptTouchMove.x == 
			app.key.ptTouchStart.x &&
			app.key.ptTouchMove.y ==
			app.key.ptTouchStart.y &&
			pointInRect(app.key.ptTouchMove, layerToRect(key)))
				print "Start", app.key.ptTouchStart
				print "Move", app.key.ptTouchMove
				app.key.isDragging = true
				app.emitter.emit "uichange", {name:"keyIsPickedUp"}
	), app.key.longpressHoldThreshold
	
isKeyInLock = () -> return rectIntersect(layerToRect(key), layerToRect(lockHitRect))

stage.onTouchMove ->
	e = Events.touchEvent(event)
	app.key.ptTouchMove = coords(point(e.clientX, e.clientY))
	
	# User has moved before longtouch threshold reached
	if app.key.isPressed && !app.key.isDragging
		killDrag()
	
	if app.key.isDragging
		if isKeyInLock()
			lock.states.switch "hoverOn"
		else
			lock.states.switch "hoverOff"
	
stage.onTouchEnd ->
	app.key.isPressed = false
	if app.key.isDragging
		if isKeyInLock()
			app.emitter.emit "uichange", {name:"keyWillUnlock"}
		else
			app.emitter.emit "uichange", {name:"keyWillDrop"}
		killDrag()
		
modal.onTap -> app.emitter.emit "uichange", {name:"hideModal"}


# Start prototype
app.emitter.emit "uichange", {name: "reset"}