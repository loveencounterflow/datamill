




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
  declare
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
realm                     = 'html'

#-----------------------------------------------------------------------------------------------------------
@$decorations = ( S ) -> $ { first, last, }, ( d, send ) =>
  if d is first
    send H.fresh_datom '^html', { realm, text: '<html><body>', ref: 'rdh/deco-1', $vnr: [ -Infinity, ], }
  if d is last
    send H.fresh_datom '^html', { realm, text: '</body></html>', ref: 'rdh/deco-2', $vnr: [ Infinity, ], }
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
    if select nxt, '>p'
      text  = "#{text}</p>"
    $vnr = VNR.deepen d.$vnr
    send H.fresh_datom '^html', { realm, text: text, ref: 'rdh/p', $vnr, }
    send d
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
  for _ in [ 1 .. ( d.linecount ? 0 ) ] by +1
    $vnr = VNR.advance $vnr
    send H.fresh_datom '^html', { realm, text: '', ref: 'rdh/mkts-1', $vnr, }
  send d


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@render = ( S ) -> new Promise ( resolve, reject ) =>
  H.register_key    S, '^html', { is_block: false, }
  H.register_realm  S, realm
  pipeline = []
  # pipeline.push @$line      S
  # pipeline.push @$decorations S
  pipeline.push @$p           S
  # pipeline.push @$mktscript   S
  pipeline.push @$blank       S
  DM.run_phase S, PD.pull pipeline...
  #.........................................................................................................
  # dbr = S.mirage.dbr
  # dbw = S.mirage.dbw
  # { to_width
  #   width_of }              = require 'to-width'
  # dbw.create_view_rows_mktscript_and_block_tags()
  # for row from dbr.$.query "select * from rows_mktscript_and_block_tags;"
  #   d = H.datom_from_row S, row
  #   urge 'µ10922', jr d
  # for row from dbr.texts_preceded_by_block_keys()
  #   $vnr    = VNR.deepen JSON.parse row.vnr
  #   text    = "#{row.prv_key}>#{row.text}"
  #   d       = H.fresh_datom '^html', { text, $vnr, ref: 'rdh/x1', }
  #   debug 'µ33431', jr d
  #   dbw.insert H.row_from_datom S, d
  # for row from dbr.texts_followed_by_block_keys()
  #   urge 'µ33431', jr row
  #   $vnr    = VNR.deepen JSON.parse row.vnr
  #   text    = "#{row.text}</#{row.nxt_key[ 1 .. ]}>"
  #   d       = H.fresh_datom '^html', { text, $vnr, ref: 'rdh/x2', }
  #   urge 'µ33431', jr d
  #   dbw.insert H.row_from_datom S, d
  #.........................................................................................................
  resolve()





