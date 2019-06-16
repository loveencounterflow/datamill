




'use strict'

############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DATAMILL/MAIN'
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
MIRAGE                    = require 'mkts-mirage'
VNR                       = require './vnr'
#...........................................................................................................
PD                        = require 'pipedreams'
{ $
  $watch
  $async
  select
  stamp }                 = PD
#...........................................................................................................
@types                    = require './types'
{ isa
  validate
  cast
  first_of
  last_of
  size_of
  type_of }               = @types
#...........................................................................................................
H                         = require './helpers'
{ cwd_abspath
  cwd_relpath
  here_abspath
  project_abspath }       = H
#...........................................................................................................
DM                        = require '..'

#-----------------------------------------------------------------------------------------------------------
@$decorations = ( S ) -> $ { first, last, }, ( d, send ) =>
  if d is first
    send H.fresh_datom '^html', { text: '<html><body>', ref: 'rdh/deco-1', $vnr: [ -Infinity, ], }
  if d is last
    send H.fresh_datom '^html', { text: '</body></html>', ref: 'rdh/deco-2', $vnr: [ Infinity, ], }
  else
    send d
  return null

#-----------------------------------------------------------------------------------------------------------
@$p = ( S ) ->
  return PD.lookaround $ ( d3, send ) =>
    [ prv, d, nxt, ] = d3
    return send d unless select d, '^mktscript'
    text = d.text
    if select prv, '<p'
      text  = "<p>#{text}"
      send stamp prv
    if select nxt, '>p'
      text  = "#{text}</p>"
      send stamp nxt
    $vnr = VNR.deepen d.$vnr
    send H.fresh_datom '^html', { text: text, ref: 'rdh/p', $vnr, }
    send stamp d
    return null

# #-----------------------------------------------------------------------------------------------------------
# @$mktscript = ( S ) -> $ ( d, send ) =>
#   if select d, '^mktscript'
#     $vnr = VNR.deepen d.$vnr
#     send H.fresh_datom '^html', { text: d.text, ref: 'rdh/mkts-1', $vnr, }
#     send d
#   else
#     send d
#   return null

#-----------------------------------------------------------------------------------------------------------
@$blank = ( S ) -> $ ( d, send ) =>
  return send d unless select d, '^blank'
  $vnr = VNR.deepen d.$vnr
  if linecount = d.linecount ? 0
    text = '\n'.repeat linecount
    send H.fresh_datom '^html', { text, ref: 'rdh/mkts-1', $vnr, }
  send stamp d

#-----------------------------------------------------------------------------------------------------------
@$set_realm = ( S, realm ) -> $ ( d, send ) =>
  return send if d.realm? then d else PD.set d, { realm, }


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@settings =
  from_realm:   'html'
  to_realm:     'html'

#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  H.register_key    S, '^html', { is_block: false, }
  H.register_realm  S, @settings.to_realm
  H.copy_realm      S, 'input', 'html'
  pipeline = []
  # pipeline.push @$decorations S
  pipeline.push @$p           S
  pipeline.push @$blank       S
  pipeline.push @$set_realm   S, @settings.to_realm
  return PD.pull pipeline...





