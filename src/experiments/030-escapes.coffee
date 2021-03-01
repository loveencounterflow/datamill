




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
#...........................................................................................................
SPX                       = require './steampipes-extra'
{ $
  $watch
  $async }                = SPX.export()
#...........................................................................................................
DATOM                     = require 'datom'
{ VNR }                   = DATOM
{ freeze
  thaw
  new_datom
  is_stamped
  select
  stamp }                 = DATOM.export()
#...........................................................................................................
types                     = require './types'
{ isa
  validate
  declare
  size_of
  type_of }               = types



#-----------------------------------------------------------------------------------------------------------
@$code_tag = ( S ) ->
  open_tag_pattern  = /// <  (?<tag> [\S]+ ) \s*  > ///
  close_tag_pattern = /// </ (?<tag> [\S]+ ) \s*  > ///
  lone_tag_pattern  = /// <  (?<tag> [\S]+ ) \s* /> ///
  return $ ( d, send ) =>
    return send d

#-----------------------------------------------------------------------------------------------------------
@$code_sf = ( S ) ->
  return $ ( d, send ) =>
    return send d

#-----------------------------------------------------------------------------------------------------------
@repeat_phase = false
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$code_tag         S
  pipeline.push @$code_sf          S
  return SPX.pull pipeline...

