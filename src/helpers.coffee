

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
#...........................................................................................................
PATH                      = require 'path'
VNR                       = require './vnr'
{ to_width
  width_of }              = require 'to-width'
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
@cwd_abspath              = CND.cwd_abspath
@cwd_relpath              = CND.cwd_relpath
@here_abspath             = CND.here_abspath
@_drop_extension          = ( path ) => path[ ... path.length - ( PATH.extname path ).length ]
@project_abspath          = ( P... ) => CND.here_abspath __dirname, '..', P...

#-----------------------------------------------------------------------------------------------------------
@format_object = ( d ) =>
  R = {}
  R[ k ] = d[ k ] for k in ( k for k of d ).sort()
  return jr R

#-----------------------------------------------------------------------------------------------------------
@new_datom = ( P ... ) =>
  R = PD.new_datom P...
  # R = PD.set R, 'vnr_txt',  ( jr R.$vnr ) if R.$vnr?
  return R

#-----------------------------------------------------------------------------------------------------------
@fresh_datom = ( P ... ) =>
  R = PD.new_datom P...
  # R = PD.set R, 'vnr_txt',  ( jr R.$vnr ) if R.$vnr?
  R = PD.set R, '$fresh',    true
  return R


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$show = ( S ) => $watch ( d ) =>
  if d.$stamped then color = CND.grey
  else
    switch d.key
      when '^word' then color = CND.gold
      else color = CND.white
  info color jr d

#-----------------------------------------------------------------------------------------------------------
@show_overview = ( S ) =>
  dbr   = S.mirage.db
  level = 0
  #.........................................................................................................
  for row from dbr.read_lines() # { limit: 30, }
    # debug 'µ10001', rpr row
    if ( row.key is '^mktscript' ) and ( row.value is '' )
      continue
    if ( row.key is '^blank' )
      echo CND.white '-'.repeat 100
      continue
    switch row.key
      when '^mktscript' then  _color  = CND.YELLOW
      when '^blank'     then  _color  = CND.grey
      when '~warning'   then  _color  = CND.RED
      when '^literal'   then  _color  = CND.GREEN
      when '<h'         then  _color  = CND.VIOLET
      when '>h'         then  _color  = CND.VIOLET
      else                    _color  = CND.white
    key   = row.key.padEnd      12
    vnr   = row.vnr_txt.padEnd  12
    value = if ( isa.text row.value ) then row.value else rpr row.value
    value = value[ .. 80 ]
    stamp = if row.stamped then 'S' else ' '
    line  = "#{vnr} #{stamp} #{key} #{rpr value}"
    line  = to_width line, 100
    dent  = '  '.repeat level
    level = switch row.key[ 0 ]
      when '<' then level + 1
      when '>' then level - 1
      else          level
    color = if row.stamped then CND.grey else ( P... ) -> CND.reverse _color P...
    # color = if row.stamped then _color else ( P... ) -> CND.reverse _color P...
    echo dent + color line
  #.........................................................................................................
  for row from dbr.get_stats()
    echo "#{row.key}: #{row.count}"
  #.........................................................................................................
  return null


#===========================================================================================================
# DB QUERIES
#-----------------------------------------------------------------------------------------------------------
@previous_line_is_blank = ( S, vnr ) =>
  return true unless ( d = @get_previous_datom S, vnr )?
  return ( d.value.match /^\s*$/ )?

#-----------------------------------------------------------------------------------------------------------
@next_line_is_blank = ( S, vnr ) =>
  return true unless ( d = @get_next_datom S, vnr )?
  return ( d.value.match /^\s*$/ )?

#-----------------------------------------------------------------------------------------------------------
@get_previous_datom = ( S, vnr ) =>
  ### TAINT consider to use types ###
  unless vnr.length is 1
    throw new Error "µ33442 `get_next_datom()` not supported for nested vnrs, got #{rpr vnr}"
  ### TAINT need inverse to advance ###
  return null unless vnr[ 0 ] > 1
  vnr_txt = jr [ vnr[ 0 ] - 1 ]
  return @datom_from_vnr S, S, vnr

#-----------------------------------------------------------------------------------------------------------
@get_next_datom = ( S, vnr ) =>
  ### TAINT consider to use types ###
  unless vnr.length is 1
    throw new Error "µ33442 `get_next_datom()` not supported for nested vnrs, got #{rpr vnr}"
  return @datom_from_vnr S, VNR.advance vnr

#-----------------------------------------------------------------------------------------------------------
@datom_from_vnr = ( S, vnr ) =>
  dbr     = S.mirage.dbr
  vnr_txt = jr vnr
  return null unless ( row = dbr.$.first_row dbr.datom_from_vnr { vnr_txt, } )?
  return @datom_from_row S, row

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@datom_from_row = ( S, row ) =>
  ### TAINT how to convert vnr in ICQL? ###
  vnr_txt     = row.vnr_txt
  $vnr        = JSON.parse vnr_txt
  R           = PD.new_datom row.key, { value: row.value, $vnr, }
  R           = PD.set R, '$stamped', true if row.stamped
  return R

#-----------------------------------------------------------------------------------------------------------
@row_from_datom = ( S, d ) =>
  ### TAINT how to convert booleans in ICQL? ###
  stamped   = if ( PD.is_stamped d ) then 1 else 0
  vnr_txt   = jr d.$vnr
  value     = if ( isa.text d.value ) then d.value else jr d.value
  R         = { key: d.key, vnr_txt, value, stamped, }
  # MIRAGE.types.validate.mirage_main_row R if do_validate
  return R

#-----------------------------------------------------------------------------------------------------------
@feed_source = ( S, source, limit = Infinity ) =>
  dbr = S.mirage.db
  nr  = 0
  #.........................................................................................................
  for row from dbr.read_unstamped_lines()
    nr += +1
    break if nr > limit
    source.send @datom_from_row S, row
  #.........................................................................................................
  source.end()
  return null

#-----------------------------------------------------------------------------------------------------------
@$feed_db = ( S ) =>
  dbw = S.mirage.dbw
  return $watch ( d ) =>
    ### TAINT how to convert vnr in ICQL? ###
    row = @row_from_datom S, d
    try
      ### TAINT consider to use upsert instead https://www.sqlite.org/lang_UPSERT.html ###
      if      d.$fresh then dbw.insert row
      else if d.$dirty then dbw.update row
    catch error
      warn "µ12133 when trying to insert or update row #{jr row}"
      warn "µ12133 an error occurred:"
      warn "µ12133 #{error.message}"
      throw error
    return null
