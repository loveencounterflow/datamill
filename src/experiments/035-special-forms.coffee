




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



###

insert code as developed in active-chr-analyzer.test.coffee

###

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
# @repeat_phase = false
# @pass_max     = 5
# @pass         = 0
# @$repeat_phase = ( S ) ->
#   return $watch { last, }, ( d ) =>
#     return null unless d is last
#     @pass += +1
#     @repeat_phase = not ( @pass >= @pass_max )
#     return null

#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  # pipeline.push @$split_on_first_active_chr         S
  # pipeline.push @$repeat_phase                      S
  return PD.pull pipeline...

