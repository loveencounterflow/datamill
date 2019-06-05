
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
@mark_preamble = ( S ) ->
  ### TAINT code duplication ###
  key         = '^line'
  pattern     = '<start/>'
  region      = 'preamble'
  dbr         = S.mirage.dbr
  dbw         = S.mirage.dbw
  rows        = dbr.$.all_rows dbr.find_eq_pattern { key, pattern, }
  first_lnr   = null
  last_lnr    = null
  switch size = size_of rows
    when 0
      warn "no document preamble found"
      ### TAINT consider to store these values in DB ###
      S.regions.preamble.from = null
      S.regions.preamble.to   = null
    when 1
      row             = rows[ 0 ]
      d               = H.datom_from_row S, row
      first_lnr       = 1
      start_lnr       = d.$vnr[ 0 ]
      last_lnr        = start_lnr - 1
      first_vnr_txt   = jr [ first_lnr ]
      start_vnr_txt   = jr [ start_lnr ]
      last_vnr_txt    = jr [ last_lnr  ]
      dbw.set_region { region, first_vnr_txt, last_vnr_txt, }
      dbw.stamp { vnr_txt: start_vnr_txt, }
      help "document preamble found on lines 1 thru #{last_lnr}"
    else
      throw new Error "µ22231 found #{size} #{pattern} tags, only up to one are allowed"
  ### TAINT consider to store these values in DB ###
  S.regions.postscript.from = first_lnr
  S.regions.postscript.to   = last_lnr
  return null

#-----------------------------------------------------------------------------------------------------------
@mark_postscript = ( S ) ->
  ### TAINT code duplication ###
  key         = '^line'
  pattern     = '<stop/>'
  dbr         = S.mirage.dbr
  dbw         = S.mirage.dbw
  rows        = dbr.$.all_rows dbr.find_eq_pattern { key, pattern, }
  first_lnr   = null
  last_lnr    = null
  switch size = size_of rows
    when 0
      warn "no document terminator found"
      ### TAINT consider to store these values in DB ###
    when 1
      row           = rows[ 0 ]
      d             = H.datom_from_row S, row
      first_lnr     = d.$vnr[ 0 ]
      ### TAINT can just ignore all <stop/> tags after first ###
      last_lnr      = dbr.$.first_value dbr.count_lines()
      first_vnr_txt = jr [ first_lnr ]
      last_vnr_txt  = jr [ last_lnr ]
      dbw.stamp { first_vnr_txt, last_vnr_txt, }
      help "document postscript found on lines #{first_lnr} thru #{last_lnr}"
    else
      throw new Error "µ22231 found #{size} #{pattern} tags, only up to one are allowed"
  ### TAINT consider to store these values in DB ###
  S.regions.postscript.from = first_lnr
  S.regions.postscript.to   = last_lnr
  return null

#-----------------------------------------------------------------------------------------------------------
### NOTE pseudo-transforms that run before first datom is sent ###
@$start = ( S ) -> $watch { first, }, ( d ) => @mark_preamble   S if d is first
@$stop  = ( S ) -> $watch { first, }, ( d ) => @mark_postscript S if d is first


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$start   S
  pipeline.push @$stop    S
  return PD.pull pipeline...
