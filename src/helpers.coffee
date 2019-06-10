

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
  cast
  declare
  size_of
  type_of }               = types
XXX_COLORIZER             = require './experiments/colorizer'

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@cwd_abspath              = CND.cwd_abspath
@cwd_relpath              = CND.cwd_relpath
@here_abspath             = CND.here_abspath
@_drop_extension          = ( path ) => path[ ... path.length - ( PATH.extname path ).length ]
@project_abspath          = ( P... ) => CND.here_abspath __dirname, '..', P...

#-----------------------------------------------------------------------------------------------------------
@badge_from_filename = ( filename ) ->
  basename  = PATH.basename filename
  return 'DATAMILL/' + ( basename .replace /^(.*?)\.[^.]+$/, '$1' ).toUpperCase()




#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@format_object = ( d ) =>
  R = {}
  R[ k ] = d[ k ] for k in ( k for k of d ).sort()
  return jr R

#-----------------------------------------------------------------------------------------------------------
@new_datom = ( P ... ) =>
  R = PD.new_datom P...
  return R

#-----------------------------------------------------------------------------------------------------------
@fresh_datom = ( P ... ) =>
  R = PD.new_datom P...
  R = PD.set R, '$fresh',    true
  return R

#-----------------------------------------------------------------------------------------------------------
@swap_key = ( d, key, $vnr = null ) ->
  ### Given a datom `d`, compute the first `$vnr` for the next level (or use the optional `$vnr` argument)
  and set the `key` on a copy. Make sure `$fresh` is set and `$dirty` is unset.
  ###
  $vnr ?= VNR.new_level d.$vnr, 1
  R     = d
  R     = PD.set    R, 'key',    key
  R     = PD.set    R, '$vnr',   $vnr
  R     = PD.set    R, '$fresh', true
  R     = PD.unset  R, '$dirty'
  return R


#===========================================================================================================
# DB QUERIES
#-----------------------------------------------------------------------------------------------------------
@row_from_vnr = ( S, vnr ) =>
  validate.vnr vnr
  dbr     = S.mirage.dbr
  vnr     = JSON.stringify vnr
  return dbr.$.first_row dbr.datom_from_vnr { vnr, }

#-----------------------------------------------------------------------------------------------------------
@datom_from_vnr = ( S, vnr ) =>
  return null unless ( row = @row_from_vnr S, vnr )?
  return @datom_from_row S, row


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@register_new_key = ( S, key, settings ) =>
  validate.datamill_register_key_settings
  db              = S.mirage.dbw
  is_block        = cast.boolean 'number', ( settings.is_block        ? false )
  has_paragraphs  = cast.boolean 'number', ( settings.has_paragraphs  ? false )
  try
    db.register_key { key, is_block, has_paragraphs, }
  catch error
    throw error unless error.message.startsWith "UNIQUE constraint failed"
    # throw new Error "µ77754 key #{rpr key} already registered"
    warn "µ77754 key #{rpr key} already registered"
  @_key_registry_cache = null
  return null

#-----------------------------------------------------------------------------------------------------------
@register_key = ( S, key, settings ) =>
  ### TAINT code duplication ###
  validate.datamill_register_key_settings
  db                    = S.mirage.dbw
  is_block              = ( settings.is_block        ? false )
  has_paragraphs        = ( settings.has_paragraphs  ? false )
  unless ( entry = db.$.first_row db.get_key_entry { key, } )?
    return @register_new_key S, key, settings
  definition            = { key, is_block, has_paragraphs, }
  entry.is_block        = cast.number 'boolean', ( entry.is_block       ? 0 )
  entry.has_paragraphs  = cast.number 'boolean', ( entry.has_paragraphs ? 0 )
  unless CND.equals definition, entry
    throw new Error "µ87332 given key definition #{jr definition} doesn't match esisting entry #{rpr entry}"
  return null

#-----------------------------------------------------------------------------------------------------------
@_key_registry_cache = null

#-----------------------------------------------------------------------------------------------------------
@get_key_registry = ( S ) =>
  return @_key_registry_cache if @_key_registry_cache?
  db                    = S.mirage.dbw
  R                     = {}
  R[ row.key ] = row for row from db.read_key_registry()
  @_key_registry_cache  = PD.freeze R
  return R


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@datom_from_row = ( S, row ) =>
  vnr         = row.vnr
  $vnr        = JSON.parse vnr
  p           = if row.p? then ( JSON.parse row.p ) else {}
  R           = PD.thaw PD.new_datom row.key, { $vnr, }
  R.dest      = row.dest
  R.ref       = row.ref
  R.text      = row.text  if row.text?
  R.$stamped  = true      if ( row.stamped ? false )
  R[ k ]      = p[ k ] for k of p when p[ k ]?
  return PD.freeze R

#-----------------------------------------------------------------------------------------------------------
@p_from_datom = ( S, d ) =>
  R     = {}
  count = 0
  for k, v of d
    continue if k is 'key'
    continue if k is 'text'
    continue if k is 'dest'
    continue if k is 'ref'
    continue if k.startsWith '$'
    continue unless v?
    count  += 1
    R[ k ]  = v
  R = null if count is 0
  return JSON.stringify R

#-----------------------------------------------------------------------------------------------------------
@row_from_datom = ( S, d ) =>
  key       = d.key
  vnr       = d.$vnr
  stamped   = d.$stamped  ? false
  dest      = d.dest      ? S.mirage.default_dest
  text      = d.text      ? null
  ref       = d.ref       ? null
  p         = @p_from_datom S, d
  R         = { key, vnr, dest, text, p, stamped, ref, }
  # R         = { key, vnr, vnr_blob, dest, text, p, stamped, }
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
    row     = @row_from_datom S, d
    methods = []
    try
      ### TAINT consider to use upsert instead https://www.sqlite.org/lang_UPSERT.html ###
      ### NOTE Make sure to test first for `$fresh`/inserts, then for `$dirty`/updates, since a `$fresh`
      datom may have undergone changes (which doesn't make the correct opertion an update). ###
      if d.$fresh
        methods.push 'insert fresh'
        dbw.insert row
      else if d.$dirty
        ### NOTE force insert when update was without effect; this happens when `$vnr` was
        affected by a `PD.set()` call (ex. `VNR.advance $vnr; send PD.set d, '$vnr', $vnr`). ###
        { changes, } = dbw.update row
        if changes is 0
          methods.push 'insert dirty'
          dbw.insert row
    catch error
      warn 'µ12133', "when trying to #{methods.join ' -> '} row"
      warn 'µ12133', jr row
      warn 'µ12133', "an error occurred:"
      warn 'µ12133', "#{error.message}"
      if error.message.startsWith 'UNIQUE constraint failed'
        urge 'µ88768', "conflict occurred because"
        urge 'µ88768', jr @row_from_vnr S, d.$vnr
        urge 'µ88768', "is already in DB"
      throw error
    return null

#===========================================================================================================
# PHASES
#-----------------------------------------------------------------------------------------------------------
@repeat_phase = ( S, phase ) =>
  validate.datamill_phase_repeat phase.repeat_phase
  return false unless phase.repeat_phase?
  return phase.repeat_phase if isa.boolean phase.repeat_phase
  return phase.repeat_phase S


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
@get_tty_width = ( S ) =>
  return R if ( R = process.stdout.columns )?
  { execSync, } = require 'child_process'
  return parseInt ( execSync "tput cols", { encoding: 'utf-8', } ), 10

#-----------------------------------------------------------------------------------------------------------
@show_overview = ( S, settings ) =>
  ### TAINT consider to convert row to datom before display ###
  line_width  = @get_tty_width S
  dbr         = S.mirage.db
  level       = 0
  omit_count  = 0
  #.........................................................................................................
  defaults =
    raw:        false
    hilite:     null
  settings = assign {}, defaults, settings
  #.........................................................................................................
  for row from dbr.read_lines() # { limit: 30, }
    if settings.raw
      info @format_object row
      continue
    # if ( row.key is '^line' ) and ( row.stamped ) and ( row.text is '' )
    #   omit_count += +1
    #   continue
    # if ( row.stamped )
    #   omit_count += +1
    #   continue
    switch row.key
      when '^line'            then  _color  = CND.YELLOW
      when '^block'           then  _color  = CND.gold
      when '^mktscript'       then  _color  = CND.RED
      when '~warning'         then  _color  = CND.RED
      when '~notice'          then  _color  = CND.cyan
      when '^literal'         then  _color  = CND.GREEN
      when '^literal-blank'   then  _color  = CND.GREEN
      when '^p'               then  _color  = CND.BLUE
      when '<h'               then  _color  = CND.VIOLET
      when '>h'               then  _color  = CND.VIOLET
      else                          _color  = @color_from_text row.key[ 1 .. ]
    #.......................................................................................................
    stamp   = if row.stamped then '*' else ''
    key     = to_width row.key,         15
    vnr     = to_width stamp + row.vnr, 12
    dest    = to_width row.dest,        4
    ref     = to_width row.ref ? '',    9
    text    = if row.text? then ( jr row.text ) else null
    p       = row.p ? null
    p       = null if ( p is 'null' )
    #.......................................................................................................
    combi   = []
    combi.push text if text?
    combi.push p    if p?
    value   = combi.join ' / '
    # value   = value[ .. 80 ]
    line    = "#{vnr}│#{dest}│#{ref}│#{key}│#{value}"
    line    = to_width line, line_width
    dent    = '  '.repeat level
    level   = switch row.key[ 0 ]
      when '<' then level + 1
      when '>' then level - 1
      else          level
    level   = Math.max level, 0
    #.......................................................................................................
    if settings.hilite? and ( settings.hilite is row.key )
      color = ( P... ) -> CND.reverse CND.pink P...
    else if ( row.stamped or row.key is '^blank' )
      color = CND.grey
    else
      color = ( P... ) -> CND.reverse _color P...
    #.......................................................................................................
    ### TAINT experimental, needs better implementation ###
    xxxxx = 44
    if row.stamped
      echo ( color line[ ... xxxxx ] ) + CND.grey line[ xxxxx .. ]
    else if line[ xxxxx ] is '"'
      echo ( color line[ ... xxxxx ] ) + CND.reverse CND.YELLOW line[ xxxxx .. ]
    else
      echo ( color line[ ... xxxxx ] ) + CND.RED line[ xxxxx .. ]
    # echo dent + color line
  #.........................................................................................................
  echo "#{omit_count} rows omitted from this view"
  for row from dbr.get_stats()
    echo "#{row.key}: #{row.count}"
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
_color_cache = {}
@color_from_text = ( text ) ->
  return R if ( R = _color_cache[ text ] )?
  R = ( P... ) -> ( XXX_COLORIZER.ansi_code_from_text text ) + CND._pen P...
  # R = ( P... ) -> CND.reverse ( XXX_COLORIZER.ansi_code_from_text text ) + CND._pen P...
  _color_cache[ text ] = R
  return R

