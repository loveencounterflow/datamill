

'use strict'


############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DATAMILL/TESTS/DB-BENCHMARK'
debug                     = CND.get_logger 'debug',     badge
warn                      = CND.get_logger 'warn',      badge
info                      = CND.get_logger 'info',      badge
urge                      = CND.get_logger 'urge',      badge
help                      = CND.get_logger 'help',      badge
whisper                   = CND.get_logger 'whisper',   badge
echo                      = CND.echo.bind CND
#...........................................................................................................
jr                        = JSON.stringify
#...........................................................................................................
PD                        = require 'pipedreams'
{ $
  $watch
  $show
  $drain
  stamp
  select }                = PD
H                         = require '../helpers'
DATAMILL                  = require '../..'
{ isa
  validate
  declare
  first_of
  last_of
  size_of
  type_of }               = DATAMILL.types
VNR                       = require '../vnr'
$fresh                    = true
first                     = Symbol 'first'
last                      = Symbol 'last'
FS                        = require 'fs'


#-----------------------------------------------------------------------------------------------------------
declare 'datamill_db_benchmark_settings', ( x ) ->
  tests:
    "x is a object":                      ( x ) -> @isa.object    x
    "x.resume_from_db is a boolean":      ( x ) -> @isa.boolean   x.resume_from_db
    "x.n is a count":                     ( x ) -> @isa.count     x.n
    "x.text is a text":                   ( x ) -> @isa.text      x.text

#-----------------------------------------------------------------------------------------------------------
@wrap_transform = ( S, settings, transform ) ->
  if settings.resume_from_db
    return H.resume_from_db_after S, { realm: 'input', }, transform
  return transform

#-----------------------------------------------------------------------------------------------------------
@$t1 = ( S, settings, X ) -> @wrap_transform S, settings, $ ( d, send ) ->
  # help 'µ12111-1', jr d
  return send d unless select d, '^mktscript'
  X.count++
  send stamp d
  text = d.text.toUpperCase()
  send PD.set ( VNR.deepen d ), { text, ref: 'bnch/t1', $fresh, }
  return null

#-----------------------------------------------------------------------------------------------------------
@$t2 = ( S, settings, X ) -> @wrap_transform S, settings, $ ( d, send ) ->
  # urge 'µ12111-2', jr d
  return send d unless select d, '^mktscript'
  X.count++
  send stamp d
  text = '*' + d.text + '*'
  send PD.set ( VNR.deepen d ), { text, ref: 'bnch/t1', $fresh, }
  return null

#-----------------------------------------------------------------------------------------------------------
@benchmark = ( settings ) -> new Promise ( resolve ) =>
  validate.datamill_db_benchmark_settings settings
  n         = 5
  #.........................................................................................................
  t0        = null
  X         = { count: 0, }
  datamill  = await @create_and_populate_db { text: settings.text, }
  #.........................................................................................................
  await do => new Promise ( resolve ) =>
    pipeline  = []
    pipeline.push H.new_db_source datamill, 'input'
    pipeline.push @$t1 datamill, settings, X
    pipeline.push @$t2 datamill, settings, X
    # pipeline.push $show()
    pipeline.push $watch { first, }, ( d ) -> t0 = Date.now() if d is first
    pipeline.push H.$feed_db datamill
    pipeline.push $drain -> resolve()
    help 'µ66743', "starting"
    PD.pull pipeline...
  #.........................................................................................................
  t1        = Date.now()
  dt        = Math.max 1, t1 - t0
  dts       = dt / 1000
  ops       = ( X.count / dt ) * 1000
  score     = ops / 10000
  dts_txt   = dts.toFixed   1
  ops_txt   = ops.toFixed   1
  score_txt = score.toFixed 3
  help()
  help 'µ34422', "resuming: #{CND.truth settings.resume_from_db}"
  help 'µ34422', "n: #{settings.n}"
  help 'µ34422', "needed #{dts_txt} s for #{X.count} operations"
  help 'µ34422', "#{ops_txt} operations per second"
  help 'µ34422', "score #{score_txt} (bigger is better)"
  resolve datamill

#-----------------------------------------------------------------------------------------------------------
@create_and_populate_db = ( settings ) -> new Promise ( resolve ) =>
  t0        = Date.now()
  FS.unlinkSync H.project_abspath 'db/datamill.db'
  datamill  = await DATAMILL.create settings
  quiet     = false
  quiet     = true
  await DATAMILL.parse_document       datamill, { quiet, }
  t1        = Date.now()
  dt        = Math.max 1, t1 - t0
  dts       = dt / 1000
  dts_txt   = dts.toFixed   1
  whisper "µ33442 needed #{dts_txt} s to prepare DB"
  # await DATAMILL.render_html          datamill, { quiet, }
  # await @_demo_list_html_rows         datamill
  #.......................................................................................................
  # await H.show_overview               datamill
  # await H.show_html                   datamill
  resolve datamill

#-----------------------------------------------------------------------------------------------------------
@get_random_words = ( n = 10, path = null ) ->
  validate.count n
  path ?= '/usr/share/dict/words'
  CP    = require 'child_process'
  words = ( ( CP.execSync "shuf -n #{n} #{path}" ).toString 'utf-8' ).split '\n'
  words = ( word.replace /'s$/g, '' for word in words )
  words = ( word for word in words when word isnt '' )
  return words

#-----------------------------------------------------------------------------------------------------------
@get_random_text = ( n = 10, path = null ) ->
  words = @get_random_words n, '/usr/share/dict/italian'
  words = ( ( if Math.random() > 0.7 then '' else word ) for word in words )
  return words.join '\n'



############################################################################################################
unless module.parent?
  # test @[ "benchmark" ], { timeout: 20, }
      # file_path:      project_abspath 'src/tests/demo-short-headlines.md'
      # file_path:      project_abspath 'src/tests/demo.md'
      # file_path:      project_abspath 'src/tests/demo-medium.md'
      # file_path:      project_abspath 'src/tests/demo-simple-paragraphs.md'
  do =>
    n        = 1000
    text     = @get_random_text n, '/usr/share/dict/italian'
    datamill = await @benchmark { n, text, resume_from_db: true, }
    datamill = await @benchmark { n, text, resume_from_db: false, }
    # await H.show_overview datamill

