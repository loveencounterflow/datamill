
'use strict'

############################################################################################################
H                         = require './helpers'
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = H.badge_from_filename __filename
debug                     = CND.get_logger 'debug',     badge
warn                      = CND.get_logger 'warn',      badge
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
  type_of }               = types


#-----------------------------------------------------------------------------------------------------------
### TAINT to be written; observe this will simplify `$blank_lines()`. ###
@$trim = ( S ) ->
  return $ ( d, send ) =>
    return send d unless select d, '^line'
    if ( new_text = d.text.trimEnd() ) isnt d.text
      d = PD.set d, 'text', new_text
    send d
    return null

#-----------------------------------------------------------------------------------------------------------
@$blank_lines = ( S ) ->
  prv_vnr       = null
  prv_dest      = null
  linecount     = 0
  send          = null
  within_blank  = false
  # is_first      = true
  #.........................................................................................................
  flush = ( advance = false ) =>
    return null unless prv_vnr?
    within_blank  = false
    if advance  then  $vnr = VNR.new_level VNR.advance  prv_vnr
    else              $vnr = VNR.new_level              prv_vnr
    send H.fresh_datom '^blank', { linecount, $vnr, dest: prv_dest, }
    linecount     = 0
  #.........................................................................................................
  return $ { last, }, ( d, send_ ) =>
    send = send_
    #.......................................................................................................
    if d is last
      flush true
      return null
    #.......................................................................................................
    is_line = select d, '^line'
    ### line contains material ###
    if is_line and ( d.text isnt '' )
      flush() if within_blank
      ### TAINT use API to ensure all pertinent values are captured ###
      prv_dest    = d.dest
      prv_vnr     = d.$vnr
      return send d
    #.......................................................................................................
    ### line is empty / blank ###
    if is_line
      send stamp d
      linecount     = 0 unless within_blank
      linecount    += +1
      within_blank  = true
    #.......................................................................................................
    ### TAINT use API to ensure all pertinent values are captured ###
    prv_dest    = d.dest
    prv_vnr     = d.$vnr
    send d
    return null

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$trim S
  pipeline.push @$blank_lines S
  return PD.pull pipeline...

