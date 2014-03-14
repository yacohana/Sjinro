'use strict'

#
# for spinner input
#
$ ->
  $('input.job-input').spinner
    spin: (event, ui) ->
      scope = angular.element("#gameSettingsForm").scope()
      scope.data[this.name] = ui.value
      scope.changedJob(this.name)
  $('input.job-input-villager').spinner()
  $('input.job-input-villager').spinner("disable")
  $('input.time-input').spinner
    spin: (event, ui) ->
      scope = angular.element("#gameSettingsForm").scope()
      scope.data[this.name] = ui.value
      scope.changedTime(this.name)

#
# load socket.io
#
socket = io.connect("http://sjinro.yacohana.info")

# for debug
socket.on "debug", (data) ->
  console.log data

# connect -> set username
socket.on "connect", (data) ->
  if user?
    if user.username?
      socket.emit "set", {username: user.username}

# set ok -> get chat
socket.on "set ok", (data) ->
  socket.emit("get chats") if !window.admin
  if window.status is "entry"
    socket.emit("get settings")
socket.emit("get chatsAdmin") if window.admin

# redirect
socket.on "redirect", (data) ->
      $().redirect data, null, "GET"

#
# angular.js
#
sjinroApp = angular.module("sjinro", ["ui.bootstrap"])

# for fix autofill
sjinroApp.directive "formAutofillFix", ->
  (scope, elem, attrs) ->
    elem.prop 'method', 'POST'
    if attrs.ngSubmit
      setTimeout ->
        elem.unbind('submit').submit (e) ->
          e.preventDefault()
          elem.find('input, textarea, select').trigger('input').trigger('change').trigger 'keydown'
          scope.$apply attrs.ngSubmit
      , 0

# Shared variable
sjinroApp.factory "Shared", ["$rootScope", ($rootScope) ->
  players = window.players
  entried = players[user.username]?
  entried:
    get: -> entried
    set: (state) ->
      entried = state
      $rootScope.$broadcast('changedEntried');
  players:
    get: -> players
    set: (newPlayers) ->
      players = newPlayers
      $rootScope.$broadcast('changedPlayers');
]

#
# signup - sigunup - signup
#
sjinroApp.controller "signupFormCtrl", ($scope) ->
  $scope.sent = false
  $scope.buttonmsg = "Sign Up"
  $scope.submit = ->
    try
      $scope.sent = true
      $scope.buttonmsg = "Signing up..."
      socket.emit "signup", $scope.data
    catch e
      $scope.$apply ->
        $scope.sent = false
      console.log e
  socket.on "signup", (data) ->
    if data.success
      $().redirect "/login",
        username: $scope.data.username
        password: $scope.data.password
    else
      $scope.$apply ->
        $scope.sent = false
        $scope.buttonmsg = "Sign Up"
        $scope.errormsg = data.message

#
# auth - auth - auth
#
sjinroApp.controller "authFormCtrl", ($scope, $timeout) ->
  $scope.sent = false
  $scope.buttonmsg = "Send"
  $scope.data = window.data
  $scope.submit = ->
    try
      $scope.sent = true
      $scope.buttonmsg = "Rewriting..."
      socket.emit "rewrite", $scope.data
    catch e
      $scope.$apply ->
        $scope.sent = false
      console.log e
  socket.on "rewrite", (data) ->
    if data.success
      $scope.$apply ->
        $scope.sent = false
        $scope.buttonmsg = "Send"
        $scope.errormsg = "Success."
      $timeout ->
        $scope.$apply ->
          $scope.errormsg = ""
      , 1000
    else
      $scope.$apply ->
        $scope.sent = false
        $scope.buttonmsg = "Send"
        $scope.errormsg = data.message


#
# game - * - players
#
sjinroApp.controller "playersCtrl", ($scope, Shared, $timeout) ->
  $scope.jobnames =
    "villager":"村人"
    "wereworf":"人狼"
    "seer":"占い師"
    "medium":"霊能者"
    "bodyguard":"狩人"
    "lunatic":"狂人"
    "freemason":"共有者"
    "fox":"妖狐"
    "cat":"猫又"
    "black":"人狼"
    "white":"人間"
  $scope.players = Shared.players.get()
  $scope.$on "changedPlayers", ->
    $scope.players = Shared.players.get()
  $scope.getStyle = (player, mode) ->
    if mode is "job"
      if (player.job is "wereworf" || player.job is "black")
        return {color: "red"}
      else
        return {}
    else
      if player.living
        return {}
      else
        return {color: "red"}
  socket.on "ready", (data) ->
    $scope.$apply ->
      $scope.players[data].ready = true
    Shared.players.set $scope.players

#
# game - entry - entry
#
sjinroApp.controller "entryFormCtrl", ($scope, Shared) ->
  $scope.entried = Shared.entried.get()
  $scope.$on "changedEntried", ->
    $scope.entried = Shared.entried.get()
  $scope.players = Shared.players.get()
  $scope.$on "changedPlayers", ->
    $scope.$apply -> $scope.players = Shared.players.get()
  if $scope.entried
    $scope.buttonmsg = "Leave"
  else
    $scope.buttonmsg = "Entry as #{user.username}"
  $scope.submit = ->
    if $scope.entried
      try
        $scope.sent = true
        socket.emit "leave", user.username
        socket.emit "setting job",
          job: "villager"
          number: -1
      catch e
        console.log e
    else
      try
        $scope.sent = true
        socket.emit "entry", user.username
      catch e
        console.log e
  socket.on "entry", (data) ->
    $scope.players[data.username] = new Object()
    $scope.players[data.username].screenname = data.screenname
    $scope.players[data.username].ready = false
    $scope.players[data.username].living = true
    Shared.players.set $scope.players
    if user.username == data.username
      $scope.$apply ->
        $scope.players[data.username].job = "villager"
        Shared.entried.set true
        $scope.sent = false
        $scope.buttonmsg = "Leave"
  socket.on "leave", (data) ->
    if user.username == data
      $scope.$apply ->
        Shared.entried.set false
        $scope.buttonmsg = "Leaving"
    delete $scope.players[data]
    Shared.players.set $scope.players

#
# game - entry - settings
#
sjinroApp.controller "gameSettingsFormCtrl", ($scope, Shared) ->
  $scope.entried = Shared.entried.get()
  $ ->
    if $scope.entried
      $('input.job-input').spinner("enable")
      $('input.time-input').spinner("enable")
    else
      $('input.job-input').spinner("disable")
      $('input.time-input').spinner("disable")
  $scope.$on "changedEntried", ->
    $scope.entried = Shared.entried.get()
    $ ->
      if $scope.entried
        $('input.job-input').spinner("enable")
        $('input.time-input').spinner("enable")
      else
        $('input.job-input').spinner("disable")
        $('input.time-input').spinner("disable")
  $scope.changedJob = (job) ->
    try
      socket.emit "setting job",
        job: job
        number: $scope.data[job]
    catch e
      console.log e
  $scope.changedTime = (time) ->
    try
      socket.emit "setting time",
        time: time
        number: $scope.data[time]
    catch e
      console.log e
  $scope.changedAlwaysDummyVillager = ->
    try
      socket.emit "setting always", $scope.data.alwaysDummyVillager
    catch e
      console.log e
  socket.on "settings", (data) ->
    $scope.$apply ->
      $scope.data = data.jobs
      $scope.data.daytime = data.times.daytime
      $scope.data.nighttime = data.times.nighttime
      $scope.data.alwaysDummyVillager = data.alwaysDummyVillager
      for job of data.jobs
        $("input[name='#{job}'].job-input").spinner("value", data.jobs[job])
      $("input[name='daytime'].time-input").spinner("value", data.times.daytime)
      $("input[name='nighttime'].time-input").spinner("value", data.times.nighttime)

#
# game - * - ready
#
sjinroApp.controller "readyFormCtrl", ($scope, Shared) ->
  $scope.sent = false
  $scope.buttonmsg = "Ready?"
  $scope.players = Shared.players.get()
  $scope.$on "changedPlayers", ->
    $scope.players = Shared.players.get()
  $scope.entried = Shared.entried.get()
  $scope.$on "changedEntried", ->
    $scope.entried = Shared.entried.get()
  if $scope.players[user.username]?
    if $scope.players[user.username].ready
      $scope.sent = true
      $scope.buttonmsg = "Ready."
  $scope.submit = ->
    try
      $scope.sent = true
      socket.emit "ready", user.username
      $scope.buttonmsg = "Ready."
    catch e
      console.log e

#
# game - night - action
#
sjinroApp.controller "actionFormCtrl", ($scope, Shared) ->
  $scope.data = new Object()
  $scope.actionable = true
  $scope.entried = Shared.entried.get()
  $scope.$on "changedEntried", ->
    $scope.entried = Shared.entried.get()
  $scope.players = Shared.players.get()
  $scope.$on "changedPlayers", ->
    $scope.$apply -> $scope.players = Shared.players.get()
  if $scope.players[user.username].ready
    $scope.actionable = false
    if $scope.players[$scope.players[user.username].action_to]?
      $scope.data.username = $scope.players[user.username].action_to
      $scope.data.judgement = $scope.players[$scope.data.username].job
      $scope.data.style = if $scope.data.judgement is 'black' then {color:'red'}
  $scope.actionSeer = (data) ->
    try
      $scope.sent = true
      socket.emit "action seer",
        username: data
        from: user.username
    catch e
      console.log e
  $scope.actionBodyguard = (data) ->
    try
      $scope.sent = true
      socket.emit "action bodyguard",
        username: data
        from: user.username
    catch e
      console.log e
  $scope.actionWereworf = (data) ->
    try
      $scope.sent = true
      socket.emit "action wereworf",
        username: data
    catch e
      console.log e
  socket.on "action seer", (data) ->
    return if !$scope.players[data.username]?
    data.style = if data.judgement is 'black' then {color:'red'}
    $scope.players[data.username].job = data.judgement
    $scope.players[user.username].ready == true
    Shared.players.set $scope.players
    $scope.$apply ->
      $scope.data = data
      $scope.actionable = false
    socket.emit "ready", user.username
  socket.on "action bodyguard", (data) ->
    return if !$scope.players[data.username]?
    $scope.players[user.username].ready == true
    Shared.players.set $scope.players
    $scope.$apply ->
      $scope.data = data
      $scope.actionable = false
    socket.emit "ready", user.username
  socket.on "action wereworf", (data) ->
    return if !$scope.players[data.username]?
    $scope.players[user.username].ready = true
    Shared.players.set $scope.players
    $scope.$apply ->
      $scope.data = data
      $scope.actionable = false
    socket.emit "ready", user.username

#
# game - execute - execute
#
sjinroApp.controller "executeFormCtrl", ($scope, Shared) ->
  $scope.data = new Object()
  $scope.actionable = true
  $scope.entried = Shared.entried.get()
  $scope.players = Shared.players.get()
  $scope.$on "changedPlayers", ->
    $scope.$apply -> $scope.players = Shared.players.get()
  if $scope.players[user.username].ready
    $scope.actionable = false
    if $scope.players[$scope.players[user.username].action_to]?
      $scope.data.username = $scope.players[user.username].action_to
  $scope.submit = (data) ->
    try
      $scope.sent = true
      socket.emit "execute",
        username: data
        from: user.username
    catch e
      console.log e
  socket.on "execute", (data) ->
    return if !$scope.players[data.username]?
    $scope.players[user.username].ready = true
    Shared.players.set $scope.players
    $scope.$apply ->
      $scope.data = data
      $scope.actionable = false
    socket.emit "ready", user.username

#
# game - * - chat
#
sjinroApp.controller "chatCtrl", ($scope, Shared) ->
  $scope.$on "changedPlayers", ->
    $scope.players = Shared.players.get()
  $scope.players = Shared.players.get()
  $scope.chatable = false
  if window.status is "entry" || window.status is "finish"
    $scope.chatable = true
  if $scope.players[user.username]?
    if (window.status is "casting") || (window.status is "night")
      if ($scope.players[user.username].job is "wereworf") || ($scope.players[user.username].job is "freemason")
          $scope.chatable = true
    if !$scope.players[user.username].living
      $scope.chatable = true
  $scope.entried = Shared.entried.get()
  $scope.$on "changedEntried", ->
    $scope.entried = Shared.entried.get()
  $scope.$on "changedPlayers", ->
    $scope.players = Shared.players.get()
  $scope.players = Shared.players.get()
  $scope.chats = new Array()
  $scope.submit = ->
    try
      socket.emit "chat", $scope.data
      $scope.data.input = ""
    catch e
      console.log e
  socket.on "chat", (data) ->
    $scope.$apply ->
      $scope.chats.push
        from: data.from
        date: data.date
        text: data.text
  socket.on "chats", (data) ->
    $scope.$apply ->
      for chatdata in data
        $scope.chats.push chatdata

#
# game - * - timer
#
sjinroApp.controller "timerCtrl", ($scope, $timeout) ->
  $scope.timer = 0
  try
    socket.emit "get timer"
  catch e
    console.log e
  socket.on "timer", (data) ->
    $scope.$apply ->
      $scope.timer = data
      $scope.timerTick()
  $scope.timerTick = ->
    if $scope.timer > 0
      $scope.timer--
      $timeout ->
        $scope.timerTick()
      , 1000

#
# admin - action - timerNext
#
sjinroApp.controller "adminFormCtrl", ($scope, $timeout) ->
  $scope.submit = ->
    socket.emit "timer next"
  $scope.changedDebugMode = ->
    socket.emit "debugMode", $scope.debugMode
  socket.on "debugMode", (data) ->
    $scope.$apply ->
      $scope.debugMode = data

#
# overlay
#
$ ->
socket.on "redirect night", (data) ->
  titleImg = $("<img src='/img/title_bl.png'>")
  titleWordImg = $("<img src='/img/title_word.png'>")
  titleImg.css
    position: 'absolute'
    width: 720
    height: 480
    "z-index": 10
  titleWordImg.css
    position: 'absolute'
    width: 720
    height: 480
    "z-index": 11
  $(window).resize ->
    pageSize = $.overlay.pageSize
    titleImg.css
      top: (pageSize[3] - 480) / 2 + $(window).scrollTop()
      left: (pageSize[2] - 720) / 2
    titleWordImg.css
      top: (pageSize[3] - 480) / 2 + $(window).scrollTop()
      left: (pageSize[2] - 720) / 2
  $(window).scroll ->
    pageSize = $.overlay.pageSize
    titleImg.css
      top: (pageSize[3] - 480) / 2 + $(window).scrollTop()
    titleWordImg.css
      top: (pageSize[3] - 480) / 2 + $(window).scrollTop()
  overlay = new $.overlay
    fade_speed: 1000
    bg_color: "#2a3753"
    opacity: 1.0
    click_close: false
  overlay.$obj.after(titleImg.hide())
  overlay.$obj.after(titleWordImg.hide())
  overlay.open ->
    pageSize = $.overlay.pageSize
    titleImg.css
      top: (pageSize[3] - 480) / 2 + $(window).scrollTop()
      left: (pageSize[2] - 720) / 2
    titleWordImg.css
      top: (pageSize[3] - 480) / 2 + $(window).scrollTop()
      left: (pageSize[2] - 720) / 2
    titleImg.fadeIn 500, ->
      titleWordImg.fadeIn 500
  setTimeout ->
    $().redirect data, null, "GET"
  , 3500

socket.on "redirect morning", (data) ->
  overlay = new $.overlay
    fade_speed: 1500
    bg_color: "#a8b6d3"
    opacity: 1.0
    click_close: false
  overlay.open ->
  setTimeout ->
    $().redirect data, null, "GET"
  , 1500

#
# for magic.css
#
$ ->
  $('img.casting').addClass('magictime vanishIn').hover ->
  　   $(this).removeClass('vanishIn')
  　   $(this).removeClass('swashIn')
  　   $(this).addClass('swashOut')
  , ->
  　   $(this).removeClass('swashOut')
  　   $(this).addClass('swashIn')
