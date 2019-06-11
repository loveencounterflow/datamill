
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
@$trim = ( S ) ->
  ref           = 'ws1/trm'
  return $ ( d, send ) =>
    return send d unless select d, '^line'
    if ( new_text = d.text.trimEnd() ) isnt d.text
      d = PD.set d, { text: new_text, ref, }
    send d
    return null

#-----------------------------------------------------------------------------------------------------------
@$blank_lines = ( S ) ->
  prv_vnr       = null
  prv_dest      = null
  linecount     = 0
  send          = null
  within_blank  = false
  ref           = 'ws1/bl'
  #.........................................................................................................
  H.register_key S, '^blank', { is_block: false, }
  #.........................................................................................................
  flush = ( advance = false ) =>
    return null unless prv_vnr?
    within_blank  = false
    $vnr = VNR.advance prv_vnr
    # if advance  then  $vnr = VNR.deepen VNR.advance  prv_vnr
    # else              $vnr = VNR.deepen              prv_vnr
    ref = 'ws1/bl-A'
    send H.fresh_datom '^blank', { linecount, $vnr, dest: prv_dest, ref, }
    linecount     = 0
  #.........................................................................................................
  return PD.mark_position $ ( pd, send_ ) =>
    { is_first
      is_last
      d       } = pd
    #.......................................................................................................
    send = send_
    #.......................................................................................................
    if is_last
      flush true
      return null
    #.......................................................................................................
    is_line = select d, '^line'
    #.......................................................................................................
    ### Insert blank if first line isn't blank: ###
    if is_line and is_first
      if ( d.text isnt '' )
        ref = 'ws1/bl-B'
        send H.fresh_datom '^blank', { linecount: 0, $vnr: [ 0 ], dest: d.dest, ref, }
    #.......................................................................................................
    return send d unless is_line
    #.......................................................................................................
    ### line is empty / blank ###
    if d.text is ''
      linecount     = 0 unless within_blank
      linecount    += +1
      within_blank  = true
      prv_dest      = d.dest
      prv_vnr       = VNR.deepen d.$vnr
      return send stamp d
    #.......................................................................................................
    ### line contains material ###
    flush false if within_blank
    ### TAINT use API to ensure all pertinent values are captured ###
    prv_dest    = d.dest
    prv_vnr     = d.$vnr
    send d
    #.......................................................................................................
    return null

#-----------------------------------------------------------------------------------------------------------
@$blank_lines_2 = ( S ) ->
  ref = 'ws1/bl2'
  H.register_key S, '^blank', { is_block: false, }
  #.........................................................................................................
  return PD.mark_position $ ( pd, send ) =>
    { is_first
      is_last
      d       } = pd
    sent_d      = false
    # if S.confine_to?
    #   debug 'µ33444', ( CND.truth is_first ), ( CND.truth is_last ), jr d
    if is_first and not select d, '^blank'
      send stamp d, { ref, }
      $vnr = VNR.deepen d.$vnr
      send H.fresh_datom '^blank', { $vnr: ( VNR.recede $vnr ), ref, }
      send PD.set d, { $vnr, $fresh: true, ref, }
      sent_d = true
    if is_last and not select d, '^blank'
      send stamp d, { ref, }
      $vnr = VNR.deepen d.$vnr
      send H.fresh_datom '^blank', { $vnr: ( VNR.advance $vnr ), ref, }
      send PD.set d, { $vnr, $fresh: true, ref, }
      sent_d = true
    send d unless sent_d
    return null

#-----------------------------------------------------------------------------------------------------------
@$blanks_at_dest_changes = ( S ) -> $ { last, }, ( d_, send ) =>
  return send d_ unless d_ is last
  db  = S.mirage.dbw
  #.........................................................................................................
  do =>
    ref = 'ws1/dst1'
    for row from db.read_changed_dest_last_lines()
      break if select row, '^blank'
      d = H.datom_from_row S, row
      send stamp d, { ref, }
      send d = VNR.deepen PD.set d, { $fresh: true, ref, }
      send H.fresh_datom '^blank', { linecount: 0, $vnr: ( VNR.advance d.$vnr ), dest: d.dest, ref, }
  #.........................................................................................................
  do =>
    ref = 'ws1/dst2'
    for row from db.read_changed_dest_first_lines()
      break if select row, '^blank'
      d = H.datom_from_row S, row
      send stamp d, { ref, }
      send d  = VNR.deepen PD.set d, { $fresh: true, ref, }
      send H.fresh_datom '^blank', { linecount: 0, $vnr: ( VNR.recede d.$vnr ), dest: d.dest, ref, }
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$trim                    S
  # pipeline.push @$blank_lines             S
  pipeline.push @$blank_lines_2           S
  pipeline.push @$blanks_at_dest_changes  S
  return PD.pull pipeline...

