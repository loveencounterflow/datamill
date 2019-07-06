
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

#-----------------------------------------------------------------------------------------------------------
@ignore_rows = ( S, first_lnr, last_lnr = null ) ->
  dbw             = S.mirage.dbw
  first_vnr_blob  = dbw.$.as_hollerith [ first_lnr ]
  last_vnr_blob   = dbw.$.as_hollerith [ last_lnr  ]
  if last_lnr?
    dbw.set_dest    { first_vnr_blob, last_vnr_blob, dest: 'ignore', }
    dbw.set_ref     { first_vnr_blob, last_vnr_blob, ref:  'stop', }
    dbw.stamp       { first_vnr_blob, last_vnr_blob, }
  else
    dbw.set_dest    { first_vnr_blob, dest: 'ignore', }
    dbw.set_ref     { first_vnr_blob, ref:  'stop', }
    dbw.stamp       { first_vnr_blob, }
  return null

#-----------------------------------------------------------------------------------------------------------
@_get_lnr = ( row ) -> ( JSON.parse row.vnr )[ 0 ]

#-----------------------------------------------------------------------------------------------------------
@mark_start = ( S ) ->
  key         = '^line'
  pattern     = '<start/>'
  dbr         = S.mirage.dbr
  rows        = dbr.$.all_rows dbr.find_eq_pattern { key, pattern, }
  switch size = size_of rows
    when 0 then null
    when 1
      lnr = @_get_lnr rows[ 0 ]
      @ignore_rows S, 1, lnr
      # info "µ33421 document start found on line #{lnr}"
    else
      lnrs = ( ( @_get_lnr row ) for row in rows ).join ', '
      throw new Error "µ22231 found #{size} #{pattern} tags, only up to one allowed (lines #{lnrs})"
  return null

#-----------------------------------------------------------------------------------------------------------
@mark_stop = ( S ) ->
  key         = '^line'
  pattern     = '<stop/>'
  dbr         = S.mirage.dbr
  rows        = dbr.$.all_rows dbr.find_eq_pattern { key, pattern, }
  switch size = size_of rows
    when 0 then null
    when 1
      lnr = @_get_lnr rows[ 0 ]
      @ignore_rows S, lnr
      # info "µ33421 document stop found on line #{lnr}"
    else
      lnrs = ( ( @_get_lnr row ) for row in rows ).join ', '
      throw new Error "µ22231 found #{size} #{pattern} tags, only up to one allowed (lines #{lnrs})"
  return null

#-----------------------------------------------------------------------------------------------------------
### NOTE pseudo-transforms that run before first datom is sent ###
@$mark_start_and_stop = ( S ) -> $watch { first, }, ( d ) =>
  return null unless d is first
  @mark_start S
  @mark_stop  S
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$mark_start_and_stop   S
  return PD.pull pipeline...

