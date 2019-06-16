




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
    else
      send d
    #.......................................................................................................
    return null

#-----------------------------------------------------------------------------------------------------------
@$assemble_paragraphs = ( S ) ->
  collector       = []
  within_p        = false
  send            = null
  leapfrogger     = ( d ) -> PD.is_stamped d
  first_vnr       = null
  H.register_key S, '^hunk', { is_block: false, }
  #.........................................................................................................
  collect = ( d ) ->
    collector ?= []
    collector.push d
    send stamp d
    return null
  #.........................................................................................................
  flush = ( d ) ->
    collect d
    text      = ( x.text for x in collector ).join '\n'
    collector = null
    $vnr      = VNR.deepen first_vnr
    send H.fresh_datom '^hunk', { text, $vnr, ref: 'pco/asp', }
    within_p  = false
    return null
  #.........................................................................................................
  return PD.leapfrog leapfrogger, PD.lookaround $ ( d3, send_ ) =>
    send              = send_
    [ prv, d, nxt, ]  = d3
    return send d unless select d, '^line'
    #.......................................................................................................
    if ( select prv, '<p' ) and ( ( select nxt, '>p' ) or ( select nxt, '^blank' ) )
      first_vnr = d.$vnr
      flush d
    #.......................................................................................................
    else if ( select prv, '<p' )
      within_p  = true
      first_vnr = d.$vnr
      collect d
    #.......................................................................................................
    else if ( select nxt, '>p' ) or ( select nxt, '^blank' )
      flush d
    #.......................................................................................................
    else if ( select d, '^line' ) and within_p
      collect d
    #.......................................................................................................
    else
      send d
    #.......................................................................................................
    return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$paragraphs          S
  # pipeline.push $watch ( d ) -> info 'µ99872', ( CND.truth PD.is_stamped d ), ( CND.white d.key ), ( CND.blue jr d )
  # pipeline.push PD.leapfrog ( ( d ) -> PD.is_stamped d ), $watch ( d ) -> info d.$vnr, d.key, d.text
  pipeline.push @$assemble_paragraphs S
  # pipeline.push @$experiment  S
  return PD.pull pipeline...

