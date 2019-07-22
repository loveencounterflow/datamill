
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
  stamp }                 = PD.export()
#...........................................................................................................
types                     = require './types'
{ isa
  validate
  declare
  size_of
  type_of }               = types

#-----------------------------------------------------------------------------------------------------------
@$ignore = ( S ) ->
  within_ignore = false
  return $ ( d, send ) =>
    return send d unless select d, '^line'
    if d.text is '<ignore>'
      within_ignore = true
      send stamp d, { dest: 'ignore', ref: 'ign', }
    else if d.text is '</ignore>'
      within_ignore = false
      send stamp d, { dest: 'ignore', ref: 'ign', }
    else if within_ignore
      send stamp d, { dest: 'ignore', ref: 'ign', }
    else
      send d
  return null

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$ignore  S
  return PD.pull pipeline...

