
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
first                     = Symbol 'first'
last                      = Symbol 'last'
DM                        = require '..'
#...........................................................................................................
SPX                       = require './steampipes-extra'
{ $
  $watch
  $async }                = SPX.export()
#...........................................................................................................
DATOM                     = require 'datom'
{ VNR }                   = DATOM
{ freeze
  thaw
  new_datom
  is_stamped
  select
  stamp }                 = DATOM.export()
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
      d = DATOM.set d, { text: new_text, ref, }
    send d
    return null

#-----------------------------------------------------------------------------------------------------------
@$group_blank_lines = ( S ) ->
  pipeline = []
  #.........................................................................................................
  $group = => SPX.$group_by ( d ) ->
    return 'blank' if ( select d, '^line' ) and ( d.text is '' )
    return 'other'
  #.........................................................................................................
  $unpack = => $ ( group, send ) =>
    buffer = group.value
    #.......................................................................................................
    if group.name is 'blank'
      d         = buffer[ 0 ]
      $vnr      = VNR.deepen d.$vnr
      linecount = buffer.length
      ref       = 'ws1/gbl'
      send H.fresh_datom '^blank', { $vnr, linecount, ref, }
      for d in buffer
        send stamp d
    #.......................................................................................................
    else
      for d in buffer
        send d
    return null
  #.........................................................................................................
  pipeline.push $group()
  pipeline.push $unpack()
  return SPX.pull pipeline...

#-----------------------------------------------------------------------------------------------------------
@$ensure_blanks_at_ends = ( S ) ->
  ### Make sure to include blanks as first and last lines in document or fragment. ###
  # first = Symbol 'first'
  # last  = Symbol 'last'
  H.register_key S, '^blank', { is_block: false, }
  #.........................................................................................................
  # return H.resume_from_db_after S, { realm: 'html', }, SPX.$mark_position $ ( pd, send ) =>
  # return H.leapfrog_stamped SPX.mark_position $ ( pd, send ) =>
  return SPX.mark_position $ ( pd, send ) =>
    { is_first
      is_last
      d       } = pd
    #.......................................................................................................
    return send d if is_stamped d
    #.......................................................................................................
    ### Make sure the first thing in document or fragment is a blank: ###
    if ( is_first ) and ( not select d, '^blank' )
      # debug '^ensure_blanks_at_ends@334^', ( stamp d )
      send stamp d
      ref   = 'ws1/ebae1'
      $vnr  = VNR.deepen d.$vnr
      # debug '^ensure_blanks_at_ends@445^', d
      # debug '^ensure_blanks_at_ends@445^', { $vnr, VNR_receded: ( VNR.recede $vnr ) }
      send H.fresh_datom '^blank', { $vnr: ( VNR.recede $vnr ), linecount: 0, ref, }
      send DATOM.set d, { $vnr, $fresh: true, ref, }
      ### If the sole line in document or fragment is not a blank line, make sure it is followed by a
      blank; we do this here and not in the next clause, below, to avoid sending a duplicate of the
      the text line: ###
      if is_last
        send H.fresh_datom '^blank', { $vnr: ( VNR.advance $vnr ), linecount: 0, ref, }
    #.......................................................................................................
    ### Make sure the last thing in document or fragment is a blank: ###
    else if ( is_last ) and ( not select d, '^blank' )
      send stamp d
      ref   = 'ws1/ebae2'
      $vnr  = VNR.deepen d.$vnr
      send H.fresh_datom '^blank', { $vnr: ( VNR.advance $vnr ), linecount: 0, ref, }
      send DATOM.set d, { $vnr, $fresh: true, ref, }
    else
      send d
    return null



#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$trim                    S
  pipeline.push @$group_blank_lines       S
  pipeline.push @$ensure_blanks_at_ends   S
  return SPX.pull pipeline...

