

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
{ to_width
  width_of }              = require 'to-width'
#...........................................................................................................
SP                        = require 'steampipes'
{ $
  $watch
  $async }                = SP.export()
#...........................................................................................................
DATOM                     = require 'datom'
{ freeze
  thaw
  new_datom
  fresh_datom
  is_stamped
  select
  stamp }                 = DATOM.export()
#...........................................................................................................
types                     = require './types'
{ isa
  validate
  cast
  declare
  equals
  size_of
  type_of }               = types
XXX_COLORIZER             = require './experiments/colorizer'
DM                        = require '..'
glob                      = require 'glob'

# debug '^555566^', ( k for k of DATOM.VNR ); process.exit 55



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

#-----------------------------------------------------------------------------------------------------------
@get_phase_names = ( S ) ->
  debug '^44447^', ( k for k of S )
  debug '^44447^', ( k for k of S.control )
  root    = cwd = __dirname
  pattern = '+([0-9]|x)-*.js'
  R       = glob.sync pattern, { root, cwd, }
  R       = ( path.replace /\.js$/, '' for path in R )
  R       = ( "./#{path}" for path in R )
  return R


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@format_object = ( d ) =>
  R = {}
  R[ k ] = d[ k ] for k in ( k for k of d ).sort()
  return jr R

#-----------------------------------------------------------------------------------------------------------
@new_datom    = ( P ... ) => new_datom    P...
@fresh_datom  = ( P ... ) => fresh_datom  P...

#-----------------------------------------------------------------------------------------------------------
@swap_key = ( d, key, $vnr = null ) ->
  ### Given a datom `d`, compute the first `$vnr` for the next level (or use the optional `$vnr` argument)
  and set the `key` on a copy. Make sure `$fresh` is set and `$dirty` is unset.
  ###
  $vnr ?= VNR.new_level d.$vnr, 1
  R     = d
  R     = SP.set    R, '$key',   key
  R     = SP.set    R, '$vnr',   $vnr
  R     = SP.set    R, '$fresh', true
  R     = SP.unset  R, '$dirty'
  return R


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@leapfrog_stamped = ( transform ) ->
  debug '^222332^', transform
  debug '^222332^', type_of transform
  return SP.leapfrog ( ( d ) -> is_stamped d ), transform

#-----------------------------------------------------------------------------------------------------------
@$filter_stamped = -> SP.$filter ( d ) -> not is_stamped d


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
  validate.datamill_register_key_settings settings
  DATOM.types.validate.datom_key key
  db              = S.mirage.dbw
  is_block        = cast 'boolean', 'float', ( settings.is_block        ? false )
  has_paragraphs  = cast 'boolean', 'float', ( settings.has_paragraphs  ? false )
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
  validate.datamill_register_key_settings settings
  DATOM.types.validate.datom_key key
  db                    = S.mirage.dbw
  is_block              = ( settings.is_block        ? false )
  has_paragraphs        = ( settings.has_paragraphs  ? false )
  unless ( entry = db.$.first_row db.get_key_entry { key, } )?
    return @register_new_key S, key, settings
  definition            = { key, is_block, has_paragraphs, }
  entry.is_block        = cast 'float', 'boolean', ( entry.is_block       ? 0 )
  entry.has_paragraphs  = cast 'float', 'boolean', ( entry.has_paragraphs ? 0 )
  unless equals definition, entry
    throw new Error "µ87332 given key definition #{jr definition} doesn't match esisting entry #{rpr entry}"
  return null

#-----------------------------------------------------------------------------------------------------------
@_key_registry_cache = null

#-----------------------------------------------------------------------------------------------------------
@get_key_registry = ( S ) =>
  return @_key_registry_cache if @_key_registry_cache?
  db                    = S.mirage.dbw
  R                     = {}
  for row from db.read_key_registry()
    for key of row
      row[ key ] = switch row[ key ]
        when 1 then true
        when 0 then false
        else row[ key ]
    R[ row.key ] = row
  @_key_registry_cache  = freeze R
  return R


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@register_realm = ( S, realm ) =>
  S.mirage.dbw.register_realm { realm }
  return null

#-----------------------------------------------------------------------------------------------------------
@copy_realm = ( S, from_realm, to_realm, selector = null ) ->
  validate.datamill_realm from_realm
  validate.datamill_realm to_realm
  validate.function selector if selector?
  dbw         = S.mirage.dbw
  #.........................................................................................................
  if selector?
    ### TAINT find a way to use fewer positional arguments ###
    select_row = ( rowid, vnr, dest, sid, realm, ref, key, text, p ) =>
      row = { vnr, dest, sid, realm, ref, key, text, p, }
      d   = @datom_from_row S, row
      return cast 'boolean', 'float', selector d
  #.........................................................................................................
  else
    select_row = ( rowid, vnr, dest, sid, realm, ref, key, text, p ) => 1
  #.........................................................................................................
  dbw.$.function 'datamill_copy_realm_select', { deterministic: false, varargs: false, }, select_row
  dbw.copy_realms { from_realm, to_realm, }
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@datom_from_row = ( S, row ) =>
  vnr         = row.vnr
  $vnr        = JSON.parse vnr
  p           = if row.p? then ( JSON.parse row.p ) else {}
  # debug '^9884234^', { $vnr, p, row, }
  R           = thaw new_datom row.key, { $vnr, }
  R.dest      = row.dest
  R.ref       = row.ref
  R.realm     = row.realm
  R.text      = row.text  if row.text?
  R.$stamped  = true      if ( row.stamped ? false )
  R[ k ]      = p[ k ] for k of p when p[ k ]?
  return freeze R

#-----------------------------------------------------------------------------------------------------------
@_properties_from_datom = ( S, d ) =>
  R     = {}
  count = 0
  for k, v of d
    continue if k is '$key'
    continue if k is 'text'
    continue if k is 'realm'
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
  key       = d.$key
  vnr       = d.$vnr
  stamped   = d.$stamped  ? false
  dest      = d.dest      ? S.mirage.default_dest
  text      = d.text      ? null
  ref       = d.ref       ? null
  realm     = d.realm     ? S.mirage.default_realm
  p         = @_properties_from_datom S, d
  R         = { key, realm, vnr, dest, text, p, stamped, ref, }
  # debug '^row_from_datom@2233-1^', d
  # debug '^row_from_datom@2233-2^', R
  # R         = { key, vnr, vnr_blob, dest, text, p, stamped, }
  # MIRAGE.types.validate.mirage_main_row R if do_validate
  return R

#-----------------------------------------------------------------------------------------------------------
@new_db_source = ( S, P... ) =>
  R = SP.new_push_source()
  @feed_source S, R, P...
  return R

#-----------------------------------------------------------------------------------------------------------
@feed_source = ( S, source, from_realm ) =>
  dbr           = S.mirage.db
  from_realm   ?= 'input'
  #.........................................................................................................
  if DM._is_reprising S
    validate.datamill_inclusive_region S.control.reprise
    { first_vnr
      last_vnr
      phase }       = S.control.reprise
    ### TAINT do casting in DB module ###
    first_vnr_blob  = dbr.$.as_hollerith first_vnr
    last_vnr_blob   = dbr.$.as_hollerith last_vnr
    rows            = dbr.read_unstamped_lines { realm: from_realm, first_vnr_blob, last_vnr_blob, }
  #.........................................................................................................
  else
    rows            = dbr.read_unstamped_lines { realm: from_realm, }
  #.........................................................................................................
  for row from rows
    # debug '^helpers/feed_source@668^ datom_from_row', @datom_from_row S, row
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
    debug '^$feed_db@3423423^', { d, }
    methods = []
    try
      ### TAINT consider to use upsert instead https://www.sqlite.org/lang_UPSERT.html ###
      ### NOTE Make sure to test first for `$fresh`/inserts, then for `$dirty`/updates, since a `$fresh`
      datom may have undergone changes (which doesn't make the correct opertion an update). ###
      if d.$fresh
        methods.push 'insert fresh'
        debug '^3423423^', 'insert fresh', { row, }
        dbw.insert row
      else if d.$dirty
        ### NOTE force insert when update was without effect; this happens when `$vnr` was
        affected by a `SP.set()` call (ex. `VNR.advance $vnr; send SP.set d, '$vnr', $vnr`). ###
        methods.push 'update dirty'
        { changes, } = dbw.update row
        debug '^3423423^', 'update dirty', { row, }
        if changes is 0
          methods.push 'insert dirty'
          debug '^3423423^', 'insert dirty', { row, }
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

#-----------------------------------------------------------------------------------------------------------
@$feed_memory = ( S ) =>
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
        affected by a `SP.set()` call (ex. `VNR.advance $vnr; send SP.set d, '$vnr', $vnr`). ###
        methods.push 'update dirty'
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

#-----------------------------------------------------------------------------------------------------------
@$resume_from_db = ( S, settings ) ->
  ### `$resume_from_db()` will feed all datoms to the DB when `settings.feed_db`; when the stream has ended,
  it will then re-read from the DB (using `settings.from_realm`). This is handy to ensure that no stamped
  datoms are in the stream below this transform, and that all datoms are properly ordered. ###
  ### TAINT use active realm as soon as it becomes available; use API to retrieve it ###
  validate.datamill_resume_from_db_settings settings
  last      = Symbol 'last'
  source    = SP.new_push_source()
  pipeline  = []
  ### TAINT make sure realm used here is same as for feed_source ###
  pipeline.push @$set_realm_where_missing S, settings.realm
  pipeline.push @$feed_db S
  pipeline.push $ { last, }, ( d, send ) =>
    return null unless d is last
    ### TAINT make sure realm used here is same as for set_realm_where_missing ###
    @feed_source S, source, settings.realm
  pipeline.push SP.$wye source
  return SP.pull pipeline...

#-----------------------------------------------------------------------------------------------------------
@resume_from_db_before = ( S, settings, transform ) ->
  pipeline  = []
  pipeline.push @$resume_from_db S, settings
  pipeline.push transform
  return SP.pull pipeline...

#-----------------------------------------------------------------------------------------------------------
@resume_from_db_after = ( S, settings, transform ) ->
  pipeline  = []
  pipeline.push transform
  pipeline.push @$resume_from_db S, settings
  return SP.pull pipeline...

#-----------------------------------------------------------------------------------------------------------
@$set_realm_where_missing = ( S, realm ) ->
  ### TAINT use active realm as soon as it becomes available; use API to retrieve it ###
  realm = realm ? S.mirage.default_realm
  return $ ( d, send ) =>
    return send if d.realm? then d else SP.set d, { realm, }


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
    switch d.$key
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
  dbr           = S.mirage.dbr
  for realm in dbr.$.all_first_values dbr.read_realm_registry()
    info 'µ13221', "Realm #{rpr realm}"
    @_show_overview S, settings, realm
  return null

#-----------------------------------------------------------------------------------------------------------
@_show_overview = ( S, settings, realm ) =>
  ### TAINT consider to convert row to datom before display ###
  line_width    = @get_tty_width S
  dbr           = S.mirage.db
  level         = 0
  omit_count    = 0
  show_stamped  = true
  show_blanks   = true
  xxx_deemphasize_closing_tags = false
  #.........................................................................................................
  defaults =
    raw:        false
    hilite:     null
  settings = assign {}, defaults, settings
  #.........................................................................................................
  for row from dbr.read_lines { realm, } # { limit: 30, }
    if settings.raw
      info @format_object row
      continue
    if ( row.$key is '^line' ) and ( row.stamped ) and ( row.text is '' )
      omit_count += +1
      continue
    if ( not show_blanks ) and ( row.$key is '^blank' )
      omit_count += +1
      continue
    if ( not show_stamped ) and row.stamped
      omit_count += +1
      continue
    switch row.$key
      when '^line'            then  _color  = CND.YELLOW
      when '^block'           then  _color  = CND.gold
      when '^mktscript'       then  _color  = CND.ORANGE
      when '~warning'         then  _color  = CND.RED
      when '~notice'          then  _color  = CND.cyan
      when '^literal'         then  _color  = CND.GREEN
      when '^literal-blank'   then  _color  = CND.GREEN
      when '<h'               then  _color  = CND.VIOLET
      when '>h'               then  _color  = CND.VIOLET
      when '^html'            then  _color  = CND.BLUE
      when '<p', '>p'         then  _color  = CND.grey
      else                          _color  = @color_from_text row.$key[ 1 .. ]
    #.......................................................................................................
    star    = if row.stamped then '*' else ''
    key     = to_width row.$key,        15
    sid     = to_width "#{row.sid}",    2
    realm   = to_width row.realm,       6
    vnr     = to_width star + row.$vnr, 12
    dest    = to_width row.dest,        4
    ref     = to_width row.ref ? '',    13
    text    = if row.text? then ( jr row.text ) else null
    p       = row.p ? null
    p       = null if ( p is 'null' )
    #.......................................................................................................
    combi   = []
    combi.push text if text?
    combi.push p    if p?
    value   = combi.join ' / '
    # value   = value[ .. 80 ]
    line    = "#{sid}#{realm}#{vnr}│#{dest}│#{ref}│#{key}│#{value}"
    line    = to_width line, line_width
    dent    = '  '.repeat level
    level   = switch row.$key[ 0 ]
      when '<' then level + 1
      when '>' then level - 1
      else          level
    level   = Math.max level, 0
    #.......................................................................................................
    if settings.hilite? and ( settings.hilite is row.$key )
      color = ( P... ) -> CND.reverse CND.pink P...
    else if row.stamped
      color = CND.grey
    else if row.$key is '^blank'
      color = CND.yellow
    else
      if xxx_deemphasize_closing_tags
        if row.$key[ 0 ] is '>'
          color = ( P... ) -> _color P...
        else
          color = ( P... ) -> CND.reverse _color P...
      else
        color = ( P... ) -> CND.reverse _color P...
    #.......................................................................................................
    ### TAINT experimental, needs better implementation ###
    if ( properties = row.p )? then properties = ( JSON.parse properties ) ? {}
    else                            properties = {}
    xxxxx = 56
    if row.stamped
      echo ( color line[ ... xxxxx ] ) + CND.grey line[ xxxxx .. ]
    else if line[ xxxxx ] is '"'
      echo ( color line[ ... xxxxx ] ) + CND.reverse CND.YELLOW line[ xxxxx .. ]
    else if properties.error?
      echo ( color line[ ... xxxxx ] ) + CND.reverse CND.pink to_width properties.error, line_width - xxxxx
    else
      echo ( color line[ ... xxxxx ] ) + CND.YELLOW line[ xxxxx .. ]
    # echo dent + color line
  #.........................................................................................................
  echo "#{omit_count} rows omitted from this view"
  for row from dbr.get_stats()
    echo "#{row.$key}: #{row.count}"
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

#-----------------------------------------------------------------------------------------------------------
@show_html = ( datamill ) ->
  line_width  = @get_tty_width null
  db          = datamill.mirage.db
  for row from db.$.query "select * from main where key = '^html' order by vnr_blob;"
    d             = @datom_from_row datamill, row
    { text
      $vnr }      = d
    lnr           = $vnr[ 0 ]
    texts         = text.split '\n'
    lnr_width     = 4
    text_width    = line_width - lnr_width - 3
    text_color    = ( P... ) -> CND.reverse CND.BLUE P...
    lnr_color     = ( P... ) -> CND.reverse CND.grey P...
    blank         = lnr_color ( ( '' ).padStart lnr_width ) + ' │'
    #.......................................................................................................
    for text, idx in texts
      text_rpr = ( text_color ' ' + to_width text, text_width )
      if ( idx is 0 ) and not ( text.match '^\s*$' )?
        lnr_rpr = lnr_color ( ( "#{lnr}" ).padStart lnr_width ) + ' │'
        echo "#{lnr_rpr}#{text_rpr}"
      else
        echo "#{blank}#{text_rpr}"
  #.........................................................................................................
  return null


