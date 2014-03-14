'use strict'

###
Module dependencies.
###
express = require("express")
routes = require("./routes")
path = require("path")
app = module.exports = express()
auth = require("./auth")
flash = require("connect-flash")

mongoose = require("mongoose")
mongoose.connect "mongodb://localhost/sjinro"
models = require("./models")

# all environments
app.set "port", process.env.PORT || 3000
app.set "views", path.join(__dirname, "views")
app.set "view engine", "jade"
app.use express.favicon()
app.use express.logger("dev")
app.use express.json()
app.use express.urlencoded()
app.use express.methodOverride()
app.use express.cookieParser()
app.use express.session({secret: "sjinro_session_secret"})

app.use flash()
app.use auth.passport.initialize()
app.use auth.passport.session()
app.use app.router
app.use express.static(path.join(__dirname, "public"))

# development only
app.use express.errorHandler()  if "development" is app.get("env")

app.get "/", routes.index
app.get "/login", routes.login
app.get "/signup", routes.signup
app.get "/rule", routes.rule
app.get "/game", auth.isLogined, routes.game
app.get "/admin", auth.isLogined, routes.admin
app.get "/authAdmin", auth.isLogined, routes.authAdmin
app.get "/userdel", auth.isLogined, routes.userdel
app.get "/useradmin", auth.isLogined, routes.useradmin
app.get "/auth", auth.isLogined, routes.auth

app.post( "/login",
  auth.passport.authenticate("local", {
    successRedirect: '/game'
    failureRedirect: '/login'
    failureFlash: true
  }),
  (req, res) -> res.redirect "/"
)

app.get "/logout", (req, res) ->
  req.logout()
  res.redirect "/"

app.get "/reset4debug", auth.isLogined, (req, res) ->
  res.redirect "/" if !req.user.admin
  models.Game.remove {}, (err) ->
    return  if err
    models.game = new models.Game()
    models.game.name = "sjinro_room"
    for i in [1..4]
      models.game.players["test"+i] = new Object()
      models.game.players["test"+i].screenname = "sc"+i
      models.game.players["test"+i].ready = true
      models.game.players["test"+i].skype = "sk"+i
      models.game.players["test"+i].living = true
      models.game.players["test"+i].killed = false
      models.game.players["test"+i].guarded = false
      models.game.players["test"+i].seered = false
      models.game.players["test"+i].visible =
        dummy: true
    models.game.players.test2.ready = false
    models.game.debug = true
    models.game.markModified()
    models.game.save()
    console.log "New game."
  res.redirect "/"

app.get "/user4debug", auth.isLogined, (req, res) ->
  res.redirect "/" if !req.user.admin
  auth = require("./auth.js")
  for i in [1..9]
    newAuth = new models.Auth()
    newAuth.username = "test" + i
    newAuth.password = auth.getHash("test" + i)
    newAuth.screenname = "sn" + i
    newAuth.skype = "sk" + i
    newAuth.admin = false
    newAuth.save()
  res.redirect "/authAdmin"


app.get "/reset", auth.isLogined, (req, res) ->
  res.redirect "/" if !req.user.admin
  models.Game.remove {}, (err) ->
    models.game = new models.Game()
    models.game.name = "sjinro_room"
    models.game.players.dummy.living = true
    models.game.debug = false
    models.game.markModified()
    models.game.save()
    console.log "New game."
  res.redirect "/"


server = require("http").createServer(app)
io = require("socket.io").listen(server,{"log level": 1})
app.set "io", io
require "./socketIO.js"



server.listen app.get("port"), ->
  console.log "Express server listening on port " + app.get("port")
