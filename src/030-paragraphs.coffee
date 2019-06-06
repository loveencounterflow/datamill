




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
@$paragraphs = ( S ) ->
  ### TAINT avoid to send `^p` after block-level element ###
  key_registry = H.get_key_registry S
  # debug 'µ11121', key_registry
  #.........................................................................................................
  return $ { first, }, ( d, send ) =>
    return if d is first
    # debug 'µ11121', jr d
    #.......................................................................................................
    if ( select d, '^blank' )
      urge 'µ11121', CND.pink "blank"
    #.......................................................................................................
    else if ( select d, '^line' )
      urge 'µ11121', CND.yellow "line", CND.reverse d.text
    #.......................................................................................................
    else if ( key_registry[ d.key ].is_block )
      color = if d.key.startsWith '<' then CND.green else CND.red
      urge 'µ11121', color "block", jr d
    #.......................................................................................................
    else
      urge 'µ11121', CND.blue "other", jr d
    #.......................................................................................................
    send d
    # return send d unless select d, '^blank'
    # send stamp d
    # $vnr    = VNR.new_level d.$vnr, 0
    # $vnr    = VNR.advance $vnr; send H.fresh_datom '^p', { blanks: d.linecount, $vnr, }

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$paragraphs  S
  return PD.pull pipeline...

