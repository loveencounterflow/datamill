
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
    # debug 'µ09012', d, stamp d
    return send stamp d if has_stopped
    return send d unless select d, '^mktscript'
    return send d unless ( d.text.match pattern )?
    send stamp d
    has_stopped = true
    $vnr        = VNR.new_level d.$vnr, 0
    message     = "µ09011 encountered `<stop>` tag; discarding rest of document"
    ### TAINT use API call ###
    $vnr        = VNR.advance $vnr; send H.fresh_datom '~notice', { message, $vnr, }
    debug 'µ09012', $vnr
    return null

#-----------------------------------------------------------------------------------------------------------
### TAINT to be written; observe this will simplify `$blank_lines()`. ###
@$trim = ( S ) ->
  return $ ( d, send ) => send d

#-----------------------------------------------------------------------------------------------------------
@$blank_lines = ( S ) ->
  prv_vnr       = null
  linecount     = 0
  send          = null
  within_blank  = false
  # is_first      = true
  #.........................................................................................................
  flush = ( advance = false ) =>
    return null unless prv_vnr?
    within_blank  = false
    if advance  then  $vnr = VNR.new_level VNR.advance  prv_vnr
    else              $vnr = VNR.new_level              prv_vnr
    send H.fresh_datom '^blank', { linecount, $vnr, }
    linecount     = 0
  #.........................................................................................................
  return $ { last, }, ( d, send_ ) =>
    send = send_
    #.......................................................................................................
    if d is last
      flush true
      return null
    #.......................................................................................................
    is_mktscript = select d, '^mktscript'
    if is_mktscript and not isa.blank_text d.text
      flush() if within_blank
      prv_vnr = d.$vnr
      return send d
    #.......................................................................................................
    if is_mktscript ### is a blank ###
      send stamp d
      linecount     = 0 unless within_blank
      linecount    += +1
      within_blank  = true
    prv_vnr       = d.$vnr
    send d
    return null

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$stop S
  pipeline.push @$trim S
  pipeline.push @$blank_lines S
  return PD.pull pipeline...

