"use strict"

mongoose = require("mongoose")
AuthSchema = new mongoose.Schema
  username:
    type: String
    required: true
  password:
    type: String
    required: true
  screenname:
    type: String
    required: true
  skype:
    type: String
    required: true
  admin:
    type: Boolean
    reqired: true

exports.Auth = mongoose.model("Auth", AuthSchema)

exports.Auth.count {}, (err, count) ->
  auth = require("./auth.js")
  if count is 0
    newAuth = new exports.Auth()
    newAuth.username = "admin"
    newAuth.password = auth.getHash("admin")
    newAuth.screenname = "管理人"
    newAuth.skype = "echo123"
    newAuth.admin = true
    newAuth.save()

GameSchema = new mongoose.Schema
  name:
    type: String
    reqired: true
  status:
    type: String
    required: true
    enum: [
      "entry"
      "casting"
      "night"
      "morning"
      "daytime"
      "execute"
      "sleep"
      "finish"
    ]
    default: "entry"
  waiting:
    type: Boolean
    required: true
    default: false
  players:
    type: mongoose.Schema.Types.Mixed
    default:
      dummy:
        screenname: "身代わり君"
        visible:
          dummy: true
        ready: true
        living: true
        killed: false
        guarded: false
        seered: false
  morningDeads: []
  voteList:[]
  daytime:
    type: Number
    default: 4
  nighttime:
    type: Number
    default: 2
  alwaysDummyVillager:
    type: Boolean
    default: true
  chats: []
  executed:
    type: String
  day:
    type: Number
    default: 0
  debug:
    type: Boolean
    default: false
  jobs:
    villager:
      type: Number
      default: 1
    wereworf:
      type: Number
      default: 0
    seer:
      type: Number
      default: 0
    medium:
      type: Number
      default: 0
    bodyguard:
      type: Number
      default: 0
    lunatic:
      type: Number
      default: 0
    freemason:
      type: Number
      default: 0
    fox:
      type: Number
      default: 0
    cat:
      type: Number
      default: 0

Game = mongoose.model("Game", GameSchema)

Game.findOne {}, (err, game) ->
  return  if err
  if game?
    exports.game = game
    console.log "Game loaded."
  else
    exports.game = new Game()
    exports.game.name = "sjinro_room"
    exports.game.save()
    console.log "New game."

exports.Game = Game