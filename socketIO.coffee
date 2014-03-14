'use strict'

app = module.parent.exports
io = app.get "io"
models = require './models'

io.sockets.on "connection", (socket) ->
  #
  # set username (client -> server)
  #
  socket.on 'set', (data) ->
    socket.set "username", data.username, ->
      if models.game.players[data.username]?
        if models.game.players[data.username].job?
          if (models.game.players[data.username].job is "wereworf") || (models.game.players[data.username].job is "freemason")
            socket.join models.game.players[data.username].job
          if !(models.game.players[data.username].living)
            socket.join "heaven"

      socket.emit "set ok"

  #
  # signup - signup - signup
  #
  socket.on 'signup', (data) ->
    models.Auth.findOne {username: data.username}, (err, auth) ->
      return if err
      if auth?
        socket.emit "signup",
          success: false
          message: "Username is already used."
      else
        console.log "user #{data.username} created"
        auth = require "./auth"
        newAuth = new models.Auth()
        newAuth.username = data.username
        newAuth.password = auth.getHash data.password
        newAuth.screenname = data.screenname
        newAuth.skype = data.skype
        newAuth.admin = false
        newAuth.save()
        socket.emit "signup",
          success: true

  #
  # auth - auth - auth
  #
  socket.on 'rewrite', (data) ->
    models.Auth.findOne {username: data.username}, (err, auth) ->
      if !auth?
        socket.emit "rewrite",
          success: false
          message: "User not found."
      else
        authsc = require "./auth"
        auth.username = data.username
        auth.password = authsc.getHash data.password
        auth.screenname = data.screenname
        auth.skype = data.skype
        auth.save()
        socket.emit "rewrite",
          success: true

  #
  # game - entry - entry
  #
  socket.on "entry", (data) ->
    models.Auth.findOne {username: data}, (err, auth) ->
      return if err
      if !auth?
        socket.emit "debug", "user not found"
      else
        if models.game.players[data]?
          socket.emit "debug", "You have already entried."
        else
          models.game.players[data] = new Object()
          models.game.players[data].screenname = auth.screenname
          models.game.players[data].skype = auth.skype
          models.game.players[data].ready = false
          models.game.players[data].job = "villager"
          models.game.players[data].living = true
          models.game.players[data].killed = false
          models.game.players[data].guarded = false
          models.game.players[data].visible = new Object()
          models.game.players[data].visible[data] = true
          models.game.markModified('players')
          models.game.save()
          io.sockets.emit "entry",
            username: data
            screenname: auth.screenname
          models.game.jobs.villager += 1
          models.game.markModified('jobs')
          io.sockets.emit "settings",
            jobs: models.game.jobs
            times:
              daytime: models.game.daytime
              nighttime: models.game.nighttime
            alwaysDummyVillager: models.game.alwaysDummyVillager

  #
  # game - entry - leave
  #
  socket.on "leave", (data) ->
    if !models.game.players[data]?
      socket.emit "debug", "You have already left."
    else
      delete models.game.players[data]
      models.game.markModified('players')
      models.game.save()
      io.sockets.emit "leave", data
      socket.emit "redirect", "/game"
      models.game.jobs.villager -= 1
      models.game.markModified('jobs')
      socket.emit "settings",
        jobs: models.game.jobs
        times:
          daytime: models.game.daytime
          nighttime: models.game.nighttime
        alwaysDummyVillager: models.game.alwaysDummyVillager

  #
  # game - entry - setting
  #

  # setting job
  socket.on "setting job", (data) ->
    if models.game.jobs[data.job]?
      if data.number >= 0
        models.game.jobs[data.job] = data.number
      models.game.jobs.villager = 0
      for username of models.game.players
        models.game.jobs.villager += 1
      for job of models.game.jobs.toObject()
        if job isnt "villager"
          models.game.jobs.villager -= models.game.jobs[job]
      if models.game.jobs.villager < 0
        for job of models.game.jobs.toObject()
          if job isnt "villager"
            while (models.game.jobs.villager<0 and models.game.jobs[job]>0) 
              models.game.jobs.villager += 1
              models.game.jobs[job] -=1
      models.game.markModified("jobs")
      models.game.save()
      io.sockets.emit "settings",
        jobs: models.game.jobs
        times:
          daytime: models.game.daytime
          nighttime: models.game.nighttime
        alwaysDummyVillager: models.game.alwaysDummyVillager

  # setting time
  socket.on "setting time", (data) ->
    return if !models.game[data.time]?
    data.number = 0 if data.number < 0
    models.game[data.time] = data.number
    models.game.markModified(data.time)
    models.game.save()
    io.sockets.emit "settings",
      jobs: models.game.jobs
      times:
        daytime: models.game.daytime
        nighttime: models.game.nighttime
      alwaysDummyVillager: models.game.alwaysDummyVillager

  # setting alwaysDummyVillager
  socket.on "setting always", (data) ->
    models.game.alwaysDummyVillager = data
    models.game.markModified("alwaysDummyVillager")
    models.game.save()
    io.sockets.emit "settings",
      jobs: models.game.jobs
      times:
        daytime: models.game.daytime
        nighttime: models.game.nighttime
      alwaysDummyVillager: models.game.alwaysDummyVillager

  # get settings
  socket.on "get settings", (data) ->
    socket.emit "settings",
      jobs: models.game.jobs
      times:
        daytime: models.game.daytime
        nighttime: models.game.nighttime
      alwaysDummyVillager: models.game.alwaysDummyVillager

  #
  # game - * - ready
  #
  socket.on "ready", (data) ->
    if !models.game.players[data]?
      socket.emit "debug", "You haven't entried."
    else
      models.game.players[data].ready = true
      models.game.markModified('players')
      models.game.save()
      if (models.game.status is "entry")||(models.game.status is "casting")||(models.game.status is "morning")||(models.game.status is "execute")||(models.game.status is "sleep")||(models.game.status is "finish")
        io.sockets.emit "ready", data
      nextStatusCheck()

  #
  # game - night - action
  #
  socket.on "action seer", (data) ->
    return if !models.game.players[data.from]?
    return if !models.game.players[data.from].living
    return if !models.game.players[data.username]?
    judgement = if models.game.players[data.username].job is "wereworf" then "black" else "white"
    models.game.players[data.from].ready = true
    models.game.players[data.from].action_to = data.username
    models.game.players[data.from].visible[data.username] = true
    models.game.players[data.username].seered = true
    models.game.markModified 'players'
    models.game.save()
    socket.emit "action seer",
      username: data.username
      judgement: judgement
  socket.on "action bodyguard", (data) ->
    return if !models.game.players[data.from]?
    return if !models.game.players[data.from].living?
    return if !models.game.players[data.username]?
    models.game.players[data.from].ready = true
    models.game.players[data.from].action_to = data.username
    models.game.players[data.username].guarded = true
    models.game.markModified 'players'
    models.game.save()
    socket.emit "action bodyguard",
      username: data.username
  socket.on "action wereworf", (data) ->
    return if !models.game.players[data.username]?
    for username, player of models.game.players
      if player.job is "wereworf"
        models.game.players[username].ready = true
        models.game.players[username].action_to = data.username
    models.game.players[data.username].killed = true
    models.game.markModified 'players'
    models.game.save()
    io.sockets.to("wereworf").emit "action wereworf",
      username: data.username

  #
  # game - night - action
  #
  socket.on "execute", (data) ->
    return if !models.game.players[data.from]?
    return if !models.game.players[data.from].living
    return if !models.game.players[data.username]?
    return if !models.game.players[data.username].living
    models.game.players[data.from].ready = true
    models.game.players[data.from].action_to = data.username
    models.game.markModified 'players'
    models.game.save()
    socket.emit "execute",
      username: data.username
  #
  # game - * - chat
  #

  # chat
  socket.on 'chat', (data) ->
    return if !data.input?
    socket.get "username", (err, username) ->
      return if !models.game.players[username]?
      sentDate = new Date()
      if models.game.status is "entry" || models.game.status is "finish"
        io.sockets.emit "chat",
          from: models.game.players[username].screenname
          text: data.input
          date: sentDate
        models.game.chats.push
          from: models.game.players[username].screenname
          to: "all"
          text: data.input
          date: sentDate
      else
        if !models.game.players[username].living
          io.sockets.to("heaven").emit "chat",
            from: models.game.players[username].screenname
            text: data.input
            date: sentDate
          models.game.chats.push
            from: models.game.players[username].screenname
            to: "heaven"
            text: data.input
            date: sentDate
        else
          if models.game.status is "casting" || models.game.status is "night"
            if (models.game.players[username].job is "wereworf") || (models.game.players[username].job is "freemason")
              io.sockets.to(models.game.players[username].job).emit "chat",
                from: models.game.players[username].screenname
                text: data.input
                date: sentDate
              models.game.chats.push
                from: models.game.players[username].screenname
                to: models.game.players[username].job
                text: data.input
                date: sentDate
      models.game.markModified('chats');
      models.game.save()

  # get chats
  socket.on 'get chats', (data) ->
    socket.get "username", (err, username) ->
      return if !username?
      chats = new Array()
      for chatdata in models.game.chats
        if models.game.players[username]?
          continue if (chatdata.to isnt models.game.players[username].job) && (chatdata.to isnt "all") && (chatdata.to isnt "heaven" || models.game.players[username].living)
        chats.push
          from: chatdata.from
          text: chatdata.text
          date: chatdata.date
      socket.emit "chats", chats
  #
  # game - * - timer
  #
  # get timer
  socket.on 'get timer', (data) ->
    socket.emit "timer", timer

  #
  # admin - action - timerNext
  #
  socket.on 'timer next', ->
    timerReset()
    nextStatusCheck()
    io.sockets.emit "redirect", "/game"

  #
  # admin - action - debug
  #
  socket.on 'debugMode', (data)->
    models.game.debug = data
    models.game.markModified "debug"
    models.game.save()
    socket.emit "redirect", "/admin"

  # get chats admin
  socket.on 'get chatsAdmin', ->
    socket.emit "chats", models.game.chats
    socket.emit "debugMode", models.game.debug

  #
  # for debug
  #
  socket.on 'debug', (data) ->
    console.log data

#
# timer
#

timer = 0

timerStart = (sec) ->
  if models.game.debug
    timer = 5
  else
    timer = sec
  timerTick()
timerTick = ->
  if timer%60 == 0
    console.log "Timer:"+timer/60
  timer--
  if timer > 0
    setTimeout ->
      timerTick()
    , 1000
  else
    if models.game.waiting
      models.game.waiting = false
      models.game.markModified "waiting"
      models.game.save()
      nextStatusCheck()
timerReset = ->
  timer = 0
  timerTick()
#
# next
#
nextStatusCheck = ->
  allReadyFlag = true
  playersNumber = 0
  for username of models.game.players
    playersNumber += 1
    allReadyFlag = false if !models.game.players[username].ready
  if playersNumber>1 && allReadyFlag && !models.game.waiting
    nextStatus()

nextStatus = ->
  if models.game.status is "finish"
    models.game.players =
      dummy:
        screenname: "身代わり君"
        visible:
          dummy: true
        ready: true
        living: true
        killed: false
        guarded: false
        seered: false
    models.game.status = "entry"
    io.sockets.emit "redirect", "/game"
    return
  if models.game.status isnt "entry"
    livingVillager = 0
    livingWereworf = 0
    livingFox = 0
    for username, player of models.game.players
      if player.living
        switch player.job
          when "wereworf"
            livingWereworf++
          when "fox"
            livingFox++
          else
            livingVillager++
    if livingVillager <= livingWereworf
      models.game.status = "finish"
    if livingWereworf <= 0
      models.game.status = "finish"
    models.game.markModified("status")
    models.game.save()
  switch models.game.status
    #
    # entry
    #
    when "entry"
      models.game.status = "casting"
      casts = new Array()
      for job of models.game.jobs.toObject()
        casts.push job for index in [0...models.game.jobs[job]]
      castingOkFlag = false
      while !castingOkFlag
        # shuffle
        i = casts.length
        while --i
          j = Math.floor(Math.random()*(i+1))
          continue if i == j
          k = casts[i]
          casts[i] = casts[j]
          casts[j] = k
        i = 0
        for username, player of models.game.players
          player.job = casts[i]
          i++
        if models.game.jobs.villager>0 && models.game.alwaysDummyVillager
          if models.game.players.dummy.job is "villager"
            castingOkFlag = true
        else
          castingOkFlag = true
      for username, player of models.game.players
        player.ready = false if username isnt "dummy"
        player.living = true
        player.killed = false
        player.seered = false
        player.guarded = false
        for userItr, playerItr of models.game.players
          player.visible[userItr] = false
          if userItr is username
            player.visible[userItr] = true
          if(playerItr.job is "wereworf") && (player.job is "wereworf")
            player.visible[userItr] = true
          if(playerItr.job is "freemason") && (player.job is "freemason")
            player.visible[userItr] = true
        #for debug
        #player.ready = true if username isnt "test2"
      models.game.markModified()
      models.game.save()
      io.sockets.emit "redirect", "/game"
    #
    # casting
    #
    when "casting"
      for username, player of models.game.players
        player.ready = true
        player.ready = false if player.job is "seer"
        player.ready = true if username is "dummy"
        player.killed = true if username is "dummy"
      models.game.status = "night"
      models.game.waiting = true
      models.game.day = 0
      models.game.markModified()
      models.game.save()
      timerStart models.game.nighttime*60
      io.sockets.emit "redirect", "/game"
    #
    # night
    #
    when "night"
      models.game.morningDeads = new Array()
      for username, player of models.game.players
        player.ready = false
        player.ready = true if username is "dummy"
        player.ready = true if !player.living
        if player.killed && player.living
          if !player.guarded && player.job isnt "fox"
            player.living = false
            models.game.morningDeads.push username
          if !player.guarded && player.job is "cat"
            wereworfs = new Array()
            for userItr, playerItr of models.game.players
              if playerItr.job is "wereworf" && playerItr.living
                wereworfs.push userItr
            if wereworfs.length > 0
              deadworf = wereworfs[Math.floor(Math.random()*(wereworfs.length-1))]
              models.game.players[deadworf].living = false
              models.game.morningDeads.push deadworf
        if player.seered && player.job is "fox"
          if player.living
            player.living = false
            models.game.morningDeads.push username
        # shuffle
        if models.game.morningDeads.length > 1
          i = models.game.morningDeads.length
          while --i
            j = Math.floor(Math.random()*(i+1))
            continue if i == j
            k = models.game.morningDeads[i]
            models.game.morningDeads[i] = models.game.morningDeads[j]
            models.game.morningDeads[j] = k
      for username, player of models.game.players
        player.ready = true if !player.living
      models.game.status = "morning"
      models.game.waiting = false
      models.game.day++
      models.game.markModified()
      models.game.save()
      io.sockets.emit "redirect morning", "/game"
    #
    # morning
    #
    when "morning"
      for username, player of models.game.players
        player.ready = true
        player.action_to = null
      models.game.status = "daytime"
      models.game.waiting = true
      models.game.markModified()
      models.game.save()
      timerStart models.game.daytime*60
      io.sockets.emit "redirect", "/game"
    #
    # daytime
    #
    when "daytime"
      for username, player of models.game.players
        player.action_to = null
        player.ready = false
        player.ready = true if username is "dummy"
        player.ready = true if !player.living
      models.game.status = "execute"
      models.game.waiting = false
      models.game.voteList = new Array()
      models.game.markModified()
      models.game.save()
      io.sockets.emit "redirect", "/game"
    #
    # execute
    #
    when "execute"
      voteHash = new Object()
      models.game.voteList = new Array()
      models.game.morningDeads = new Array()
      for username, player of models.game.players
        player.ready = false
        player.ready = true if username is "dummy"
        player.ready = true if !player.living
        if player.living && player.action_to?
          if models.game.players[player.action_to]?
            if models.game.players[player.action_to].living
              if voteHash[player.action_to]?
                voteHash[player.action_to]++
              else
                voteHash[player.action_to] = 1
      for username, voted of voteHash
        models.game.voteList.push
          username: username
          voted: voted
      models.game.voteList.sort (a,b) ->
        if a.voted < b.voted then 1 else -1
      if models.game.voteList.length > 1 && models.game.voteList[0].voted == models.game.voteList[1].voted
        models.game.status = "execute"
      else
        models.game.executed = models.game.voteList[0].username
        models.game.players[models.game.executed].living = false
        models.game.morningDeads = new Array()
        if models.game.players[models.game.executed].job is "cat"
          livingPlayers = new Array()
          for userItr, playerItr of models.game.players
            if playerItr.living
              livingPlayers.push userItr
          if livingPlayers.length > 0
              deadPlayer = livingPlayers[Math.floor(Math.random()*(livingPlayers.length-1))]
            models.game.players[deadPlayer].living = false
            models.game.morningDeads.push deadPlayer
        for username, player of models.game.players
          player.ready = true if !player.living
        models.game.status = "sleep"
        models.game.waiting = false
      models.game.markModified()
      models.game.save()
      io.sockets.emit "redirect", "/game"
    #
    # sleep
    #
    when "sleep"
      for username, player of models.game.players
        player.ready = true
        player.ready = false if player.job is "seer"
        player.ready = false if player.job is "bodyguard"
        player.ready = false if player.job is "wereworf"
        player.ready = true if username is "dummy"
        player.ready = true if !player.living
        player.action_to = null
        if player.job is "medium"
          player.visible[models.game.executed] = true
      models.game.status = "night"
      models.game.waiting = true
      models.game.markModified()
      models.game.save()
      timerStart models.game.nighttime*60
      io.sockets.emit "redirect night", "/game"
    when "finish"
      for username, player of models.game.players
        player.ready = false
        player.ready = true if username is "dummy"
        player.action_to = null
      models.game.waiting = false
      models.game.markModified()
      models.game.save()
      io.sockets.emit "redirect", "/game"