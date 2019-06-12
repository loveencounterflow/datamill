
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
DM                        = require '..'
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
@$group_by = ( S ) =>
  ### TAINT, simplify, generalize, implement as standard transform `$group_by()` ###
  group   = null
  buffer  = null
  return $ { last, }, ( d, send ) =>
    if d is last
      if buffer? and buffer.length > 0
        send [ group, buffer, ]
        buffer = null
      return
    return send d unless select d, '^line'
    if d.text is ''
      if group? and ( group isnt 'blank' )
        send [ group, buffer, ]
        buffer = null
      group   = 'blank'
      buffer ?= []
      buffer.push d
    else
      if group? and ( group isnt 'line' )
        send [ group, buffer, ]
        buffer = null
      group   = 'line'
      buffer ?= []
      buffer.push d
    return null

#-----------------------------------------------------------------------------------------------------------
@$blank_lines_1 = ( S ) ->
  pipeline = []
  #.........................................................................................................
  $unpack = ( S ) =>
    return $ ( d, send ) =>
      return send d unless isa.list d
      [ group, buffer, ] = d
      switch group
        #...................................................................................................
        when 'line'
          send sub_d for sub_d in buffer
        #...................................................................................................
        when 'blank'
          d1        = buffer[ 0 ]
          $vnr      = VNR.deepen d1.$vnr
          linecount = buffer.length
          ref       = 'ws1/bl1'
          send H.fresh_datom '^blank', { $vnr, linecount, ref, }
          send ( stamp sub_d ) for sub_d in buffer
        #...................................................................................................
        else
          throw new Error "µ11928 unknown group #{rpr group}"
      return null
  #.........................................................................................................
  pipeline.push @$group_by S
  pipeline.push $unpack S
  return PD.pull pipeline...

#-----------------------------------------------------------------------------------------------------------
@$blank_lines_2 = ( S ) ->
  ### Make sure to include blanks as first and last lines in document or fragment. ###
  H.register_key S, '^blank', { is_block: false, }
  #.........................................................................................................
  return PD.mark_position $ ( pd, send ) =>
    { is_first
      is_last
      d       } = pd
    #.......................................................................................................
    ### Make sure the first thing in document or fragment is a blank: ###
    if is_first and not select d, '^blank'
      send stamp d
      ref   = 'ws1/b2-1'
      $vnr  = VNR.deepen d.$vnr
      send H.fresh_datom '^blank', { $vnr: ( VNR.recede $vnr ), linecount: 0, ref, }
      send PD.set d, { $vnr, $fresh: true, ref, }
      ### If the sole line in document or fragment is not a blank line, make sure it is followed by a
      blank; we do this here and not in the next clause, below, to avoid sending a duplicate of the
      the text line: ###
      if is_last
        send H.fresh_datom '^blank', { $vnr: ( VNR.advance $vnr ), linecount: 0, ref, }
    #.......................................................................................................
    ### Make sure the last thing in document or fragment is a blank: ###
    else if is_last and not select d, '^blank'
      send stamp d
      ref   = 'ws1/b2-2'
      $vnr  = VNR.deepen d.$vnr
      send H.fresh_datom '^blank', { $vnr: ( VNR.advance $vnr ), linecount: 0, ref, }
      send PD.set d, { $vnr, $fresh: true, ref, }
    else
      send d
    return null



#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$trim                    S
  pipeline.push @$blank_lines_1           S
  pipeline.push @$blank_lines_2           S
  return PD.pull pipeline...

