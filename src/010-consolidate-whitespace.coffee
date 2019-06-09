
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
  is_first_line = true
  #.........................................................................................................
  H.register_key S, '^blank', { is_block: false, }
  #.........................................................................................................
  flush = ( advance = false ) =>
    return null unless prv_vnr?
    within_blank  = false
    $vnr = VNR.advance  prv_vnr
    # if advance  then  $vnr = VNR.deepen VNR.advance  prv_vnr
    # else              $vnr = VNR.deepen              prv_vnr
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
    #.......................................................................................................
    ### Insert blank if first line isn't blank: ###
    if is_line and is_first_line
      is_first_line = false
      if ( d.text isnt '' )
        send H.fresh_datom '^blank', { linecount: 0, $vnr: [ 0 ], dest: d.dest, }
    #.......................................................................................................
    ### line contains material ###
    if is_line and ( d.text isnt '' )
      flush false if within_blank
      ### TAINT use API to ensure all pertinent values are captured ###
      prv_dest    = d.dest
      prv_vnr     = d.$vnr
      return send d
    #.......................................................................................................
    ### line is empty / blank ###
    if is_line
      send d = stamp VNR.deepen d
      linecount     = 0 unless within_blank
      linecount    += +1
      within_blank  = true
    #.......................................................................................................
    ### TAINT use API to ensure all pertinent values are captured ###
    prv_dest    = d.dest
    prv_vnr     = d.$vnr
    send d
    return null

#-----------------------------------------------------------------------------------------------------------
@$blanks_at_dest_changes = ( S ) -> $ { last, }, ( d, send ) =>
  return send d unless d is last
  db = S.mirage.dbw
  for row from db.read_changed_dest_last_lines()
    d = H.datom_from_row S,row
    break if select d, '^blank'
    send stamp d
    d       = VNR.deepen d
    send d
    $vnr    = VNR.advance d.$vnr
    d       = H.fresh_datom '^blank', { linecount: 0, $vnr, dest: d.dest, }
    send d
    debug 'µ44552-1', jr d
  for row from db.read_changed_dest_first_lines()
    d = H.datom_from_row S,row
    break if select d, '^blank'
    send stamp d
    d       = VNR.deepen d
    send d
    $vnr    = VNR.recede d.$vnr
    d       = H.fresh_datom '^blank', { linecount: 0, $vnr, dest: d.dest, }
    send d
    debug 'µ44552-2', jr d
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$trim                    S
  pipeline.push @$blank_lines             S
  pipeline.push @$blanks_at_dest_changes  S
  return PD.pull pipeline...

