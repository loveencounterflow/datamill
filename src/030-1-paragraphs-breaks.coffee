




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
#...........................................................................................................
# ### Whether in-place updates are OK ###
# prefer_updates = true


#-----------------------------------------------------------------------------------------------------------
@$breaks = ( S ) ->
  H.register_key S, '^break', { is_block: false, }
  key_registry    = H.get_key_registry S
  prv_was_break   = false
  #.........................................................................................................
  return $ { first, }, ( d, send ) =>
    return if d is first
    return send d if PD.is_stamped d
    #.......................................................................................................
    if ( select d, '^blank' )
      if ( not prv_was_break )
        ### TAINT code duplication ###
        ref           = 'pbr/br1'
        dest          = d.dest
        $vnr          = VNR.deepen d.$vnr, 0
        send H.fresh_datom '^break', { $vnr: ( VNR.advance $vnr ), dest, ref, }
        prv_was_break = true
      return send d
    #.......................................................................................................
    is_block  = key_registry[ d.key ].is_block
    is_opener = select d, '<'
    is_closer = select d, '>'
    #.......................................................................................................
    if ( not prv_was_break ) and is_block
      if is_opener
        ### TAINT code duplication ###
        ref           = 'pbr/br2'
        dest          = d.dest
        $vnr          = VNR.deepen d.$vnr, 0
        send H.fresh_datom '^break', { $vnr: ( VNR.recede $vnr ), dest, ref, }
        send PD.set d, { $vnr, ref, }
        prv_was_break = true
        send stamp d
        return
      else
        ### TAINT code duplication ###
        ref           = 'pbr/br3'
        dest          = d.dest
        $vnr          = VNR.deepen d.$vnr, 0
        send PD.set d, { $vnr, ref, }
        send H.fresh_datom '^break', { $vnr: ( VNR.advance $vnr ), dest, ref, }
        prv_was_break = true
        send stamp d
        return
    #.......................................................................................................
    prv_was_break = false
    send d
    # return send d unless select d, '^blank'
    # send stamp d
    # $vnr    = VNR.deepen d.$vnr, 0
    # $vnr    = VNR.advance $vnr; send H.fresh_datom '^p', { blanks: d.linecount, $vnr, }


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$breaks      S
  return PD.pull pipeline...

