




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
Md                        = require 'markdown-it'
md                        = new Md()
TIMETUNNEL                = require 'timetunnel'


#-----------------------------------------------------------------------------------------------------------
@$consolidate_paragraphs = ( S ) ->
  collector = null
  $vnr      = null
  send      = null
  #.........................................................................................................
  flush = ->
    return if ( not collector? ) or ( collector.length is 0 )
    text      = collector.join '\n'
    send H.fresh_datom '^block', { text, $vnr, }
    collector = null
    $vnr      = null
    return null
  #.........................................................................................................
  return $ { last, }, ( d, send_ ) =>
    send = send_
    if d is last
      flush()
    else if select d, '^line'
      $vnr       ?= VNR.new_level d.$vnr, 1
      collector  ?= []
      collector.push d.text
      send stamp d
    else if select d, '^blank'
      flush()
      send d
    else
      send d
    return null

#-----------------------------------------------------------------------------------------------------------
@$parse = ( S ) ->
  guards    = 'äöüßp'
  intalph   = '0123456789'
  tnl       = new TIMETUNNEL.Timetunnel { guards, intalph, }
  # tnl.add_tunnel TIMETUNNEL.tunnels.remove_backslash
  # tnl.add_tunnel TIMETUNNEL.tunnels.keep_backslash
  tnl.add_tunnel TIMETUNNEL.tunnels.htmlish
  #.........................................................................................................
  return $ ( d, send ) =>
    return send d unless ( select d, '^mktscript' )
    #.......................................................................................................
    original_text = d.text
    tunneled_text = tnl.hide original_text
    modified_text = md.renderInline tunneled_text
    text          = tnl.reveal modified_text
    # info 'µ33344', ( CND.white rpr text ), ( CND.yellow md.parse text )
    #.......................................................................................................
    info 'µ33344', ( CND.white  jr original_text )
    info 'µ33344', ( CND.red    jr tunneled_text )
    info 'µ33344', ( CND.yellow jr modified_text )
    info 'µ33344', ( CND.green  jr text )
    info 'µ33344'
    #.......................................................................................................
    send stamp d
    $vnr  = VNR.new_level d.$vnr, 0
    $vnr  = VNR.advance $vnr; send H.fresh_datom '^mktscript', { text, $vnr, }
    send

#-----------------------------------------------------------------------------------------------------------
@repeat_phase = false
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$consolidate_paragraphs  S
  pipeline.push @$parse                   S
  return PD.pull pipeline...

