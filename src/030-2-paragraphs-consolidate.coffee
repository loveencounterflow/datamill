




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
#...........................................................................................................


#-----------------------------------------------------------------------------------------------------------
@$paragraphs = ( S ) ->
  H.register_key S, '<p', { is_block: true, }
  H.register_key S, '>p', { is_block: true, }
  key_registry    = H.get_key_registry S
  within_p        = false
  block_depth     = 0
  prv_was_break   = false
  prv_line_vnr    = null
  #.........................................................................................................
  return $ ( d, send ) =>
    return send d if PD.is_stamped d
    #.......................................................................................................
    is_block  = key_registry[ d.key ].is_block
    is_opener = select d, '<'
    is_closer = select d, '>'
    if is_block
      if is_opener then block_depth++
      else              block_depth--
    return send d unless block_depth is 0
    #.......................................................................................................
    if select d, '^break'
      prv_was_break = true
      send stamp d
      debug 'µ440098', jr d
      if within_p
        ref           = 'µ15603'
        dest          = d.dest
        throw new Error "µ44982" unless prv_line_vnr?
        $vnr          = VNR.new_level prv_line_vnr, 0
        prv_line_vnr  = null
        # $vnr          = VNR.new_level d.$vnr, 0
        # $vnr          = VNR.advance $vnr; send PD.set d, '$vnr', $vnr
        $vnr          = VNR.advance $vnr; send H.fresh_datom '>p', { $vnr, dest, ref, }
        within_p      = false
        prv_was_break = false
    #.......................................................................................................
    if select d, '^line'
      prv_line_vnr = d.$vnr
      if prv_was_break
        ref           = 'µ15604'
        dest          = d.dest
        $vnr          = VNR.new_level d.$vnr, 0
        $vnr          = VNR.advance $vnr; send H.fresh_datom '<p', { $vnr, dest, ref, }
        $vnr          = VNR.advance $vnr; send PD.set d, '$vnr', $vnr
        prv_line_vnr  = $vnr
        within_p      = true
        prv_was_break = false
        send stamp d
      else
        send d
    #.......................................................................................................
    send d

#-----------------------------------------------------------------------------------------------------------
@$experiment = ( S ) ->
  H.register_key S, '^x', { is_block: false, }
  #.........................................................................................................
  return $ { last, }, ( d, send ) =>
    return send d unless d is last
    send H.fresh_datom '^x', { $vnr: [ 10, -1, ], dest: 'xxx', }
    send H.fresh_datom '^x', { $vnr: [ 10,  0, ], dest: 'xxx', }
    return null

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$paragraphs  S
  pipeline.push @$experiment  S
  return PD.pull pipeline...

