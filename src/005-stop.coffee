
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
@$stop = ( S ) ->
  pattern     = /// ^ < stop \/? > $ ///
  has_stopped = false
  return $ ( d, send ) =>
    # debug 'µ09012', d
    # debug 'µ09012', stamp d
    return send stamp d if has_stopped
    return send d unless select d, '^line'
    return send d unless ( d.text.match pattern )?
    send stamp d
    has_stopped = true
    $vnr        = VNR.new_level d.$vnr, 0
    message     = "µ09011 encountered `<stop>` tag; discarding rest of document"
    ### TAINT use API call ###
    $vnr        = VNR.advance $vnr; send H.fresh_datom '~notice', { message, $vnr, }
    return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$stop S
  return PD.pull pipeline...

