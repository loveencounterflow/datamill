




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
require                   './exception-handler'
first                     = Symbol 'first'
last                      = Symbol 'last'
VNR                       = require './vnr'
#...........................................................................................................
PD                        = require 'pipedreams'
{ $
  $watch
  $async
  select
  stamp }                 = PD
#...........................................................................................................
types                     = require './types'
{ isa
  validate
  declare
  size_of
  last_of
  type_of }               = types
#...........................................................................................................
# ### Whether in-place updates are OK ###
# prefer_updates = true


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
### TAINT consider to move this to pipedreams ###
@$validate_symmetric_keys = ( settings ) ->
  stack = []
  vnr   = null
  return $ { last, }, ( d, send ) =>
    #.......................................................................................................
    if d is last
      unless isa.empty stack
        is_vnr  = jr vnr
        message = [ 'µ44333', ]
        message = [ "at document end (VNR #{is_vnr}), encountered dangling open tag(s):", ]
        for entry in stack
          was_vnr = jr entry.$vnr
          message.push "`>#{entry.name}` (VNR #{was_vnr})"
        throw new Error message.join ' '
      return null
    #.......................................................................................................
    vnr   = d.$vnr
    key   = d.key
    sigil = key[ 0 ]
    name  = key[ 1 .. ]
    #.......................................................................................................
    switch sigil
      when '<'
        stack.push { name, $vnr: d.$vnr, }
      when '>'
        entry = last_of stack
        unless entry.name is name
          ### TAINT make configurable whether to throw or warn ###
          was_vnr = jr entry.$vnr
          is_vnr  = jr vnr
          throw new Error "µ44332 expected `>#{entry.name}` (VNR #{was_vnr}), found `#{key}` (VNR #{is_vnr})"
        stack.pop()
      else
        send d
    return null

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$validate_symmetric_keys  S
  return PD.pull pipeline...

