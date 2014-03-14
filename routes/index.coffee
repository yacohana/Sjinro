models = require "../models.js"

exports.index = (req, res) ->
  res.render "index",
    title: "Top"
    user: req.user

exports.login = (req, res) ->
  res.render "login",
    title: "Login"
    user: req.user
    message: req.flash("error")

exports.signup = (req, res) ->
  res.render "signup",
    title: "Sign up"
    user: req.user

exports.auth = (req, res) ->
  res.render "auth",
    title: "Auth"
    user: req.user

exports.rule = (req, res) ->
  res.render "rule",
    title: "Rule"

exports.game = (req, res) ->
  if (models.game.status isnt "entry" && !models.game.players[req.user.username]?)
    res.render "error-notEntry",
      title: "Error"
    return
  if models.game.players[req.user.username]?
    req.user.job = models.game.players[req.user.username].job
    if models.game.status is "finish"
      players = new Object()
      livingWereworf = 0
      livingFox = 0
      for username of models.game.players
        players[username] = new Object()
        players[username].screenname = models.game.players[username].screenname
        players[username].living = models.game.players[username].living
        players[username].ready = models.game.players[username].ready
        players[username].job = models.game.players[username].job
        if players[username].living
          switch players[username].job
            when "wereworf"
              livingWereworf++
            when "fox"
              livingFox++
      if livingFox > 0
        winner = "fox"
      else
        if livingWereworf <= 0
          winner = "villager"
        else
          winner = "wereworf"
      res.render "finish",
        title: "Game Over"
        user: req.user
        players: players
        status: models.game.status
        winner: winner
      return
    if !models.game.players[req.user.username].living
      players = new Object()
      for username of models.game.players
        players[username] = new Object()
        players[username].screenname = models.game.players[username].screenname
        players[username].skype = models.game.players[username].skype
        players[username].living = models.game.players[username].living
        players[username].ready = models.game.players[username].ready
        players[username].action_to = models.game.players[username].action_to
        players[username].job = models.game.players[username].job
      res.render "heaven",
        title: "Heaven"
        user: req.user
        players: players
        status: models.game.status
        voteList: models.game.voteList
      return
  players = new Object()
  for username of models.game.players
    players[username] = new Object()
    players[username].screenname = models.game.players[username].screenname
    players[username].skype = models.game.players[username].skype
    players[username].living = models.game.players[username].living
    if (models.game.status is "entry")||(models.game.status is "casting")||(models.game.status is "morning")||(models.game.status is "execute")||(models.game.status is "sleep")
      players[username].ready = models.game.players[username].ready
    if (models.game.status is "execute")||(models.game.status is "sleep")
      players[username].action_to = models.game.players[username].action_to
    if username is req.user.username
      players[username].ready = models.game.players[username].ready
      players[username].action_to = models.game.players[username].action_to
      players[username].job = models.game.players[username].job
    if models.game.players[req.user.username]?
      if (models.game.players[req.user.username].job is "wereworf" || models.game.players[req.user.username].job is "freemason")
        if models.game.players[req.user.username].visible[username]
          players[username].job = models.game.players[username].job
      if models.game.players[req.user.username].job is "seer" || models.game.players[req.user.username].job is "medium"
        if models.game.players[req.user.username].visible[username]
          players[username].job = if models.game.players[username].job is "wereworf" then "black" else "white"
  res.render models.game.status,
    title: switch models.game.status
      when "entry"
        "Entrance"
      when "casting"
        "Entrance"
      when "night"
        "Night Day.#{models.game.day}"
      when "morning"
        "Morning Day.#{models.game.day}"
      when "daytime"
        "Daytime Day.#{models.game.day}"
      when "execute"
        "Daytime Day.#{models.game.day}"
      when "sleep"
        "Daytime Day.#{models.game.day}"
    user: req.user
    players: players
    status: models.game.status
    day: models.game.day
    executed: models.game.executed
    morningDeads: models.game.morningDeads
    voteList: models.game.voteList

exports.admin = (req, res) ->
  res.redirect "/" if !req.user.admin
  req.user.job = "wereworf"
  res.render "admin",
    title: "Admin"
    user: req.user
    players: models.game.players
    admin: true
    status: "night"

exports.authAdmin = (req, res) ->
  res.redirect "/" if !req.user.admin
  models.Auth.find {}, (err, auths) ->
    res.render "authAdmin",
      title: "Admin"
      admin: true
      auths: auths

exports.userdel = (req, res) ->
  res.redirect "/authAdmin" if req.query?
  res.redirect "/authAdmin" if req.query.username?
  res.redirect "/" if !req.user.admin && req.query.username isnt req.user.username
  models.Auth.remove {"username":req.query.username}, (err) ->
    console.log "Deleted user."
  if !req.user.admin
    res.redirect "/authAdmin"
  else
    res.redirect "/"

exports.useradmin = (req, res) ->
  res.redirect "/authAdmin" if req.query?
  res.redirect "/authAdmin" if req.query.username?
  res.redirect "/" if !req.user.admin
  models.Auth.findOne {"username":req.query.username}, (err, auth) ->
    auth.admin = !auth.admin
    auth.save()
  res.redirect "/authAdmin"



###
    app.post( "/login",
  passport.authenticate("local", {
    successRedirect: '/game'
    failureRedirect: '/login'
    failureFlash: true
  }),
###