

'use strict'

############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DATAMILL/TESTS/BASIC'
log                       = CND.get_logger 'plain',     badge
info                      = CND.get_logger 'info',      badge
whisper                   = CND.get_logger 'whisper',   badge
alert                     = CND.get_logger 'alert',     badge
debug                     = CND.get_logger 'debug',     badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
urge                      = CND.get_logger 'urge',      badge
echo                      = CND.echo.bind CND
#...........................................................................................................
PATH                      = require 'path'
FS                        = require 'fs'
OS                        = require 'os'
test                      = require 'guy-test'
#...........................................................................................................
{ to_width
  width_of }              = require 'to-width'
#...........................................................................................................
{ jr
  assign }                = CND
defer                     = setImmediate
{ inspect, }              = require 'util'
xrpr                      = ( x ) -> inspect x, { colors: yes, breakLength: Infinity, maxArrayLength: Infinity, depth: Infinity, }
#...........................................................................................................
SP                        = require 'steampipes'
{ $
  $watch
  $async
  select
  stamp }                 = SP.export()
#...........................................................................................................
DATOM                     = require 'datom'
{ VNR }                   = DATOM
{ freeze
  thaw
  new_datom
  is_stamped
  select
  stamp }                 = DATOM.export()
#...........................................................................................................
types                     = require '../types'
{ isa
  validate
  declare
  first_of
  cast
  last_of
  size_of
  type_of }               = types
#...........................................................................................................
DM                        = require '../..'
H                         = require '../helpers'
{ cwd_abspath
  cwd_relpath
  here_abspath
  project_abspath }       = H


#-----------------------------------------------------------------------------------------------------------
as_padded_lines = ( text ) -> ( ( to_width line, 100 ) for line in text.split '\n' )

#-----------------------------------------------------------------------------------------------------------
as_numbered_lines = ( text ) ->
  R = []
  for line, idx in as_padded_lines text
    nr = idx + 1
    R.push ( to_width "#{nr}", 3 ) + CND.reverse line
  return R.join '\n'

#-----------------------------------------------------------------------------------------------------------
query_tables = ( dm ) ->
  table_names = [
    'main'
    'keys'
    'realms'
    'sources' ]
  for table_name in table_names
    # sql = "select count(*) from #{table_name};"
    sql = "select * from #{table_name};"
    for row from dm.mirage.dbr.$.query sql
      info table_name, row
  return null

#-----------------------------------------------------------------------------------------------------------
@[ "stamped datoms must be stamped (duh)" ] = ( T, done ) ->
  dm    = await DM.create { text: 'some text here', } ### TAINT bug in mirage prevents using empty text ###
  $vnr  = [ 123, ]
  d1    = new_datom '^line', { $vnr, text: "XXX" }
  row   = H.row_from_datom dm, d1
  T.eq d1,  { '$vnr': [ 123 ], text: 'XXX', '$key': '^line' }
  T.eq row, { key: '^line', realm: 'input', vnr: [ 123 ], dest: 'main', text: 'XXX', p: 'null', stamped: false, ref: null }
  d2    = stamp d1
  T.ok d1 isnt d2
  row   = H.row_from_datom dm, d2
  T.eq d2,  { '$vnr': [ 123 ], text: 'XXX', '$key': '^line', '$stamped': true }
  T.eq row, { key: '^line', realm: 'input', vnr: [ 123 ], dest: 'main', text: 'XXX', p: 'null', stamped: true, ref: null }
  dbw   = dm.mirage.dbw
  # urge '^98^', dbw.$.pragma 'foreign_keys = off';
  # query_tables dm
  T.eq ( dbw.insert row ), { changes: 1, lastInsertRowid: 2 }
  # query_tables dm
  vnr_blob = Buffer.from '4d405ec000000000004c', 'hex'
  T.eq ( H.row_from_vnr   dm, $vnr ), { vnr: '[123]', stamped: 1, dest: 'main', sid: 1, realm: 'input', ref: null, key: '^line', text: 'XXX', p: 'null', vnr_blob, }
  T.eq ( H.datom_from_vnr dm, $vnr ), { '$vnr': [ 123 ], '$key': '^line', dest: 'main', ref: null, realm: 'input', text: 'XXX', '$stamped': true }
  #.........................................................................................................
  ### Make sure casting between booleans and floats works as expected: ###
  T.eq ( cast 'boolean',  'float',    false ), 0
  T.eq ( cast 'boolean',  'float',    true  ), 1
  T.eq ( cast 'float',    'boolean',  0     ), false
  T.eq ( cast 'float',    'boolean',  1     ), true
  #.........................................................................................................
  done()


#-----------------------------------------------------------------------------------------------------------
@[ "xxx2" ] = ( T, done ) ->
  probes_and_matchers = [
    [ "A short text", "<p>A short text</p>", null, ]
    # ["# A Headline","<h1>A Headline</h1>",null]
    # ["\nA short text\n\n\n","\n<p>A short text</p>\n\n\n",null]
    # ["First.\nSecond.","<p>First.\nSecond.</p>",null]
    # ["First.\n\nSecond.","<p>First.</p>\n\n<p>Second.</p>",null]
    # ["# A Headline\n\nA paragraph","<h1>A Headline</h1>\n\n<p>A paragraph</p>",null]
    # ["# A Headline\n\n```\nCode\n```","<h1>A Headline</h1>\n\n<pre><code>\nCode\n</code></pre>",null]
    # ["# A Headline\n\n> Quote","<h1>A Headline</h1>\n\n<blockquote>\n<p>Quote</p>\n</blockquote>",null]
    # ["# A Headline\n\n> Quote\n","<h1>A Headline</h1>\n\n<blockquote>\n<p>Quote</p>\n</blockquote>\n",null]
    # ["\n# A Headline\n\n> Quote\n","\n<h1>A Headline</h1>\n\n<blockquote>\n<p>Quote</p>\n</blockquote>\n",null]
    # ["> quote 1\n> quote 2\n> quote 3","<blockquote>\n<p>quote 1\nquote 2\nquote 3</p>\n</blockquote>",null]
    # ["> quote 1\n> quote 2\n> quote 3\n","<blockquote>\n<p>quote 1\nquote 2\nquote 3</p>\n</blockquote>\n",null]
    # ["```\nCODE\n```","<pre><code>\nCODE\n</code></pre>",null]
    # ["```\nCODE\n```\n","<pre><code>\nCODE\n</code></pre>\n",null]
    # ["> ```\n> CODE\n> ```\n","<blockquote>\n<pre><code>\nCODE\n</code></pre>\n</blockquote>\n",null]
    # ["> ```\n> CODE\n> ```\n>","<blockquote>\n<pre><code>\nCODE\n</code></pre>\n\n</blockquote>",null]
    # ["> ```\n> CODE\n> ```\n> ","<blockquote>\n<pre><code>\nCODE\n</code></pre>\n\n</blockquote>",null]
    # ["> ```\n> CODE\n> ```\n> next line\n> yet another line","<blockquote>\n<pre><code>\nCODE\n</code></pre>\n<p>next line\nyet another line</p>\n</blockquote>",null]
    # ["> ```\n> CODE\n> ```","<blockquote>\n<pre><code>\nCODE\n</code></pre>\n</blockquote>",null]
    # ["\n# A Headline\n\n> Quote\n> ```\n> CODE\n> ```","\n<h1>A Headline</h1>\n\n<blockquote>\n<p>Quote\n<pre><code>\nCODE\n</code></pre>\n</blockquote>",null]
    ]
  #.........................................................................................................
  quiet = false
  quiet = true
  for [ probe, matcher, error, ] in probes_and_matchers
    await T.perform probe, matcher, error, -> new Promise ( resolve ) ->
      datamill  = await DM.create { text: probe, }
      # datamill  = await DM.create { text: probe, db_path: ':memory:', }
      await DM.parse_document datamill, { quiet, }
      await DM.render_html    datamill, { quiet, }
      result    = await DM.retrieve_html  datamill, { quiet: true, }
      if not quiet
        urge 'µ77782', '\n' + as_numbered_lines probe
        info 'µ77782', '\n' + as_numbered_lines result
        # await H.show_overview   datamill
        # await H.show_html       datamill
      resolve result
      return null
  #.........................................................................................................
  defer -> done()
  return null

# #-----------------------------------------------------------------------------------------------------------
# @[ "VNRs must be unique" ] = ( T, done ) ->
#   text    = "A short text" # "<p>A short text</p>"
#   dm      = await DM.create { text, }
#   { dbw } = dm.mirage
#   #.........................................................................................................
#   dbw.$.run "drop index main_pk;"
#   # dbw.insert H.row_from_datom dm, { '$vnr': [ 2, ], text: 'XXX', '$key': '^line' }
#   # dbw.insert H.row_from_datom dm, { '$vnr': [ 2, ], text: 'XXX', '$key': '^line' }
#   #.........................................................................................................
#   done()

#-----------------------------------------------------------------------------------------------------------
@[ "VNRs must be unique" ] = ( T, done ) ->
  probes_and_matchers = [
    [ "A short text", "<p>A short text</p>", null, ]
    # ["```\nCODE\n```","<pre><code>\nCODE\n</code></pre>",null]
    # ["\n# A Headline\n\n> Quote\n> ```\n> CODE\n> ```","\n<h1>A Headline</h1>\n\n<blockquote>\n<p>Quote\n<pre><code>\nCODE\n</code></pre>\n</blockquote>",null]
    # ["First.\n\nSecond.","<p>First.</p>\n\n<p>Second.</p>",null]
    # ["# A Headline\n\n> Quote\n","<h1>A Headline</h1>\n\n<blockquote>\n<p>Quote</p>\n</blockquote>\n",null]
    ]
  #.........................................................................................................
  result  = null
  quiet   = true
  quiet   = false
  for [ probe, matcher, error, ] in probes_and_matchers
    dm  = await DM.create { text: probe, }
    # dm  = await DM.create { text: probe, db_path: ':memory:', }
    #.......................................................................................................
    ### Drop index so erroneous VNR duplicates won't trigger an error in the DB: ###
    dm.mirage.dbw.$.run "drop index main_pk;"
    #.......................................................................................................
    debug '^984232-1^', await DM.parse_document dm, { quiet, }
    sql = """
      with v1 as ( select
          *,
          count(*) over ( partition by vnr ) as dcount
        from main )
      select * from v1
        where dcount > 1
        order by
          vnr_blob,
          ref;"""
    #.......................................................................................................
    dcount = 0
    for row from dm.mirage.dbr.$.query sql
      dcount++
      delete row.vnr_blob
      warn row
    #.......................................................................................................
    if dcount > 0
      T.fail "found #{dcount} duplicate rows"
    else
      T.ok true
    #.......................................................................................................
    # debug '^984232-1^', await DM.render_html    dm, { quiet, }
    # result    = await DM.retrieve_html  dm, { quiet: true, }
    if not quiet
      urge 'µ77782', '\n' + as_numbered_lines probe
      info 'µ77782', '\n' + as_numbered_lines result if result?
      # await H.show_overview   dm
      # await H.show_html       dm
  #.........................................................................................................
  done()
  return null



############################################################################################################
unless module.parent?
  # test @, { timeout: 5000, }
  # test @[ "stamped datoms must be stamped (duh)" ]
  test @[ "VNRs must be unique" ]
  # test @[ "xxx2" ], { timeout: 1e4, }
  # test @[ "xxx2" ], { timeout: 1e4, }
  # test @[ "wye with duplex pair"            ]


