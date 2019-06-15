




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


  # key_registry    = H.get_key_registry S
  # block_depth     = 0
    # is_block  = key_registry[ d.key ].is_block
    # is_opener = select d, '<'
    # is_closer = select d, '>'
    # if is_block
    #   if is_opener then block_depth++
    #   else              block_depth--
    # return send d unless block_depth is 0

#-----------------------------------------------------------------------------------------------------------
@$paragraphs = ( S ) ->
  H.register_key S, '<p', { is_block: true, }
  H.register_key S, '>p', { is_block: true, }
  within_p        = false
  prv_was_blank   = false
  #.........................................................................................................
  return $ ( d, send ) =>
    #.......................................................................................................
    if select d, '^blank'
      if within_p
        send stamp d
        ref           = 'pco/p1'
        dest          = d.dest
        $vnr          = VNR.deepen d.$vnr, 0
        send PD.set d, { $vnr, dest, ref, $fresh: true, }
        send H.fresh_datom '>p', { $vnr: ( VNR.recede $vnr ), dest, ref, }
        within_p      = false
      else
        send d
      prv_was_blank = true
    #.......................................................................................................
    else if select d, '^line'
      if prv_was_blank
        ref           = 'pco/p2'
        dest          = d.dest
        $vnr          = VNR.deepen d.$vnr, 0
        send H.fresh_datom '<p', { $vnr: ( VNR.recede $vnr ), dest, ref, }
        send PD.set d, { $vnr, ref, }
        within_p      = true
        send stamp d
      else
        send d
      prv_was_blank = false
    #.......................................................................................................
    send d

# #-----------------------------------------------------------------------------------------------------------
# @$experiment = ( S ) ->
#   H.register_key S, '^x', { is_block: false, }
#   #.........................................................................................................
#   return $ { last, }, ( d, send ) =>
#     return send d unless d is last
#     send H.fresh_datom '^x', { $vnr: [ 10, -1, ], dest: 'xxx', }
#     send H.fresh_datom '^x', { $vnr: [ 10,  0, ], dest: 'xxx', }
#     return null

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$paragraphs  S
  # pipeline.push @$experiment  S
  return PD.pull pipeline...

