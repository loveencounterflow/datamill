




'use strict'

############################################################################################################
H                         = require './helpers'
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = H.badge_from_filename __filename
debug                     = CND.get_logger 'debug',     badge
warn                      = CND.get_logger 'warn',      badge
alert                     = CND.get_logger 'alert',     badge
info                      = CND.get_logger 'info',      badge
urge                      = CND.get_logger 'urge',      badge
help                      = CND.get_logger 'help',      badge
whisper                   = CND.get_logger 'whisper',   badge
echo                      = CND.echo.bind CND
{ jr
  assign }                = CND
#...........................................................................................................
first                     = Symbol 'first'
last                      = Symbol 'last'
VNR                       = require './vnr'
#...........................................................................................................
PD                        = require 'steampipes'
{ $
  $watch
  $async
  select
  stamp }                 = PD.export()
#...........................................................................................................
types                     = require './types'
{ isa
  validate
  declare
  size_of
  last_of
  type_of }               = types
#...........................................................................................................
{ xr, }                   = require './xr'


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
### TAINT consider to move this to steampipes ###
@$validate_symmetric_keys = ( settings ) ->
  stack = []
  vnr   = null
  return PD.mark_position $ ( pd, send ) =>
    { is_first
      is_last
      d       } = pd
    #.......................................................................................................
    if is_last
      unless isa.empty stack
        is_vnr  = jr vnr
        ref     = if d.ref? then "ref: #{d.ref}" else "(no ref)"
        message = [ 'µ44333', ]
        message = [ "at document end (VNR #{is_vnr}, #{ref}), encountered dangling open tag(s):", ]
        for entry in stack
          was_vnr = jr entry.$vnr
          message.push "`>#{entry.name}` (VNR #{was_vnr})"
        message = message.join ' '
        send PD.new_datom '~error', { message, $: d, }
      return null
    #.......................................................................................................
    vnr     = d.$vnr
    is_vnr  = jr vnr
    key     = d.key
    sigil   = key[ 0 ]
    name    = key[ 1 .. ]
    ref     = if d.ref? then "ref: #{d.ref}" else "(no ref)"
    #.......................................................................................................
    switch sigil
      when '<'
        stack.push { name, $vnr: d.$vnr, }
      when '>'
        if isa.empty stack
          message = "µ44332 extraneous closing key `>#{name}` found at (VNR #{is_vnr}, #{ref}), stack empty"
          send PD.new_datom '~error', { message, $: d, }
        entry = last_of stack
        unless entry.name is name
          ### TAINT make configurable whether to throw or warn ###
          was_vnr = jr entry.$vnr
          message = "µ44332 expected `>#{entry.name}` (VNR #{was_vnr}), found `#{key}` (VNR #{is_vnr}, #{ref})"
          send PD.new_datom '~error', { message, $: d, }
        stack.pop()
      else
        send d
    return null

#-----------------------------------------------------------------------------------------------------------
@$complain_on_error = ->
  count = 0
  return $ { last, }, ( d, send ) =>
    if d is last
      if count > 0
        alert "µ77874 found #{count} faults"
      return null
    return send d unless select d, '~error'
    send PD.set d.$, { error: d.message, }
    return null

#-----------------------------------------------------------------------------------------------------------
@$exit_on_error = ->
  messages = []
  return $ { last, }, ( d, send ) =>
    if d is last
      if messages.length > 0
        message = messages.join '\n\n'
        throw new Error "µ77874 found #{messages.length} faults: \n\n#{message}"
    return send d unless select d, '~error'
    messages.push d.message
    return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$validate_symmetric_keys   S
  pipeline.push @$complain_on_error         S
  # pipeline.push @$exit_on_error             S
  return PD.pull pipeline...

