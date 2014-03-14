'use strict'

crypto = require("crypto")
models = require("./models")

secretKey = "secret_of_Sjinro"

exports.getHash = (target) ->
  sha = crypto.createHmac("sha256", secretKey)
  sha.update target
  sha.digest("hex")

exports.passport = require("passport")
LocalStrategy = require("passport-local").Strategy

exports.passport.serializeUser( (auth, done) ->
  done(null, {username: auth.username, _id: auth._id})
)
exports.passport.deserializeUser( (serializedUser, done) ->
  models.Auth.findById( serializedUser._id, (err, auth) ->
    done(err, auth)
  )
)

exports.passport.use( new LocalStrategy(
  (username, password, done) ->
    models.Auth.findOne({username: username}, (err, auth) ->
      return done(err) if err
      if !auth
        return done(null, false, {message: "User not Found"}) 
      hashedPassword = exports.getHash(password)                    
      if auth.password isnt hashedPassword
        return done(null, false, {message: "Incorrect Password"})
      done(null, auth)
    )
  )
)

exports.isLogined = (req, res, next) ->
  if req.isAuthenticated()
    return next()
  res.redirect("/login")