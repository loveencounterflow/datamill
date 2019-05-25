

'use strict'



############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DATAMILL/HELPERS'
debug                     = CND.get_logger 'debug',     badge
warn                      = CND.get_logger 'warn',      badge
info                      = CND.get_logger 'info',      badge
urge                      = CND.get_logger 'urge',      badge
help                      = CND.get_logger 'help',      badge
whisper                   = CND.get_logger 'whisper',   badge
echo                      = CND.echo.bind CND
{ jr
  assign }                = CND
PD                        = require 'pipedreams'
#...........................................................................................................
types                     = require './types'
{ isa
  validate
  declare
  size_of
  type_of }               = types

#-----------------------------------------------------------------------------------------------------------
@new_level = ( vnr, nr = 1 ) =>
  ### Given a `mirage` instance and a vectorial line number `vnr`, return a copy of `vnr`, call it
  `vnr0`, which has an index of `0` appended, thus representing the pre-first `vnr` for a level of lines
  derived from the one that the original `vnr` pointed to. ###
  validate.nonempty_list vnr
  R = assign [], vnr
  R.push nr
  return R

#-----------------------------------------------------------------------------------------------------------
@advance = ( vnr ) =>
  ### Given a `mirage` instance and a vectorial line number `vnr`, return a copy of `vnr`, call it
  `vnr0`, which has its last index incremented by `1`, thus representing the vectorial line number of the
  next line in the same level that is derived from the same line as its predecessor. ###
  validate.nonempty_list vnr
  R                    = assign [], vnr
  R[ vnr.length - 1 ] += +1
  return R
