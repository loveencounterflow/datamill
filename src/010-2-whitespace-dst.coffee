
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
@$blanks_at_dest_changes = ( S ) -> $ { last, }, ( d_, send ) =>
  return send d_ unless d_ is last
  db  = S.mirage.dbw
  #.........................................................................................................
  do =>
    ref = 'ws1/dst1'
    for row from db.read_changed_dest_last_lines()
      break if select row, '^blank'
      d = H.datom_from_row S, row
      send stamp d
      send d = VNR.deepen PD.set d, { $fresh: true, ref, }
      send H.fresh_datom '^blank', { linecount: 0, $vnr: ( VNR.advance d.$vnr ), dest: d.dest, ref, }
  #.........................................................................................................
  do =>
    ref = 'ws1/dst2'
    for row from db.read_changed_dest_first_lines()
      break if select row, '^blank'
      d = H.datom_from_row S, row
      send stamp d
      send d  = VNR.deepen PD.set d, { $fresh: true, ref, }
      send H.fresh_datom '^blank', { linecount: 0, $vnr: ( VNR.recede d.$vnr ), dest: d.dest, ref, }
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$blanks_at_dest_changes  S
  return PD.pull pipeline...

