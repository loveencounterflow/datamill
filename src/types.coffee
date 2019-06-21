


'use strict'


############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'MKTS-PARSER/TYPES'
debug                     = CND.get_logger 'debug',     badge
alert                     = CND.get_logger 'alert',     badge
whisper                   = CND.get_logger 'whisper',   badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
urge                      = CND.get_logger 'urge',      badge
info                      = CND.get_logger 'info',      badge
jr                        = JSON.stringify
Intertype                 = ( require 'intertype' ).Intertype
intertype                 = new Intertype module.exports

#-----------------------------------------------------------------------------------------------------------
@declare 'datamill_phase_repeat', ( x ) ->
  return true unless x?
  return true if @isa.boolean x
  return @isa.function x

#-----------------------------------------------------------------------------------------------------------
@declare 'datamill_region', ( x ) ->
  tests:
    "x is an inclusive or an exclusive region": ( x ) ->
      is_inclusive = @isa.datamill_inclusive_region x
      is_exclusive = @isa.datamill_exclusive_region x
      return ( is_inclusive or is_exclusive ) and not ( is_inclusive and is_exclusive )

#-----------------------------------------------------------------------------------------------------------
@declare 'datamill_exclusive_region', ( x ) ->
  tests:
    "x is an object":                 ( x ) -> @isa.object x
    "x.start_vnr is a vnr":           ( x ) -> isa.vnr x.start_vnr
    "x.stop_vnr is a vnr":            ( x ) -> isa.vnr x.stop_vnr

#-----------------------------------------------------------------------------------------------------------
@declare 'datamill_inclusive_region', ( x ) ->
  tests:
    "x is an object":                 ( x ) -> @isa.object x
    "x.first_vnr is a vnr":           ( x ) -> isa.vnr x.first_vnr
    "x.last_vnr is a vnr":            ( x ) -> isa.vnr x.last_vnr

#-----------------------------------------------------------------------------------------------------------
@declare 'datamill_reprising_message', ( x ) ->
  tests:
    "x is an object":                   ( x ) -> @isa.object x
    "x.key is '^reprise'":              ( x ) -> @isa.key is '^reprise'
    "x.phase is a nonempty_text":       ( x ) -> isa.nonempty_text x.phase
    "x is a datamill_region":           ( x ) -> isa.datamill_region x

#-----------------------------------------------------------------------------------------------------------
@declare 'datamill_register_key_settings', ( x ) ->
  tests:
    "x is a object":                  ( x ) -> @isa.object    x
    "x.is_block is a boolean":        ( x ) -> @isa.boolean   x.is_block
    "x.has_paragraphs is a ?boolean": ( x ) -> ( not x.has_paragraphs? ) or @isa.boolean x.has_paragraphs

#-----------------------------------------------------------------------------------------------------------
@declare 'datamill_realm', ( x ) ->
  tests:
    "x is a nonempty text":           ( x ) -> @isa.nonempty_text x

#-----------------------------------------------------------------------------------------------------------
@declare 'datamill_run_phase_settings', ( x ) ->
  tests:
    "x is a object":                      ( x ) -> @isa.object          x
    "x.from_realm is a datamill_realm":   ( x ) -> @isa.datamill_realm  x.from_realm
    # "x.to_realm is a datamill_realm":     ( x ) -> @isa.datamill_realm  x.to_realm
    # "x.transform is a function":          ( x ) -> @isa.function        x.transform

#-----------------------------------------------------------------------------------------------------------
@declare 'datamill_resume_from_db_settings', ( x ) ->
  tests:
    "x is a object":                      ( x ) -> @isa.object          x
    "x.phase is a datamill_realm":        ( x ) -> @isa.datamill_realm  x.realm

# #-----------------------------------------------------------------------------------------------------------
# @declare 'datamill_copy_realms_settings', ( x ) ->
#   tests:
#     "x is a object":                      ( x ) -> @isa.object        x
#     "x.from is a object":                 ( x ) -> @isa.object        x.from
#     "x.to is a object":                   ( x ) -> @isa.object        x.to
#     "x.from.realm is a nonempty text":    ( x ) -> @isa.nonempty_text x.from.realm
#     "x.from.select is a ?function":       ( x ) -> ( not x.from.select?) or ( @isa.function x.from.select )
#     "x.to.realm is a nonempty text":      ( x ) -> @isa.nonempty_text x.to.realm


  # tests:
  #   "optional x is function or boolean":
#     "x is a object":                          ( x ) -> @isa.object          x
#     "x has key 'key'":                        ( x ) -> @has_key             x, 'key'
#     "x has key 'vlnr_txt'":                   ( x ) -> @has_key             x, 'vlnr_txt'
#     "x has key 'value'":                      ( x ) -> @has_key             x, 'value'
#     "x.key is a nonempty text":               ( x ) -> @isa.nonempty_text   x.key
#     "x.vlnr_txt is a nonempty text":          ( x ) -> @isa.nonempty_text   x.vlnr_txt
#     "x.vlnr_txt starts, ends with '[]'":      ( x ) -> ( x.vlnr_txt.match /^\[.*\]$/ )?
#     "x.vlnr_txt is a JSON array of integers": ( x ) ->
#       # debug 'µ55589', x
#       ( @isa.list ( lst = JSON.parse x.vlnr_txt ) ) and \
#       ( lst.every ( xx ) => ( @isa.integer xx ) and ( @isa.positive xx ) )


