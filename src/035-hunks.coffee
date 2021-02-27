




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



#-----------------------------------------------------------------------------------------------------------
@$assemble_hunks = ( S ) ->
  prv_was_line    = false
  send            = null
  first_vnr       = null
  collector       = null
  H.register_key S, '^hunk', { is_block: false, }
  #.........................................................................................................
  collect = ( d ) ->
    unless collector?
      first_vnr = d.$vnr
      collector = []
    collector.push d
    send stamp d
    return null
  #.........................................................................................................
  flush = ->
    return null unless collector?
    text          = ( x.text for x in collector ).join '\n'
    collector     = null
    $vnr          = VNR.deepen first_vnr
    prv_was_line  = false
    send H.fresh_datom '^hunk', { text, $vnr, ref: 'pco/asp', }
    return null
  #.........................................................................................................
  return H.leapfrog_stamped $ { last, }, ( d, send_ ) =>
    send              = send_
    #.......................................................................................................
    if d is last
      return flush()
    #.......................................................................................................
    unless select d, '^line'
      flush()
      return send d
    #.......................................................................................................
    return collect d


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$assemble_hunks S
  return PD.pull pipeline...

