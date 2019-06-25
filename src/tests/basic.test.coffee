

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
PD                        = require 'pipedreams'
{ $
  $async }                = PD
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
PD                        = require 'pipedreams'
{ $
  $watch
  $async
  select
  stamp }                 = PD
#...........................................................................................................
types                     = require '../types'
{ isa
  validate
  declare
  first_of
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
@[ "xxx" ] = ( T, done ) ->
  probes_and_matchers = [
    [ "A short text", "<p>A short text</p>", null, ]
    ["# A Headline","<h1>A Headline</h1>",null]
    ["\nA short text\n\n\n","\n<p>A short text</p>\n\n\n",null]
    ["First.\nSecond.","<p>First.\nSecond.</p>",null]
    ["First.\n\nSecond.","<p>First.</p>\n\n<p>Second.</p>",null]
    ["# A Headline\n\nA paragraph","<h1>A Headline</h1>\n\n<p>A paragraph</p>",null]
    ["# A Headline\n\n```\nCode\n```","<h1>A Headline</h1>\n\n<pre><code>\nCode\n</code></pre>",null]
    ["# A Headline\n\n> Quote","<h1>A Headline</h1>\n\n<blockquote>\n<p>Quote</p>\n</blockquote>",null]
    ["# A Headline\n\n> Quote\n","<h1>A Headline</h1>\n\n<blockquote>\n<p>Quote</p>\n</blockquote>\n",null]
    ["\n# A Headline\n\n> Quote\n","\n<h1>A Headline</h1>\n\n<blockquote>\n<p>Quote</p>\n</blockquote>\n",null]
    ["> quote 1\n> quote 2\n> quote 3","<blockquote>\n<p>quote 1\nquote 2\nquote 3</p>\n</blockquote>",null]
    ["> quote 1\n> quote 2\n> quote 3\n","<blockquote>\n<p>quote 1\nquote 2\nquote 3</p>\n</blockquote>\n",null]
    ["```\nCODE\n```","<pre><code>\nCODE\n</code></pre>",null]
    ["```\nCODE\n```\n","<pre><code>\nCODE\n</code></pre>\n",null]
    ["> ```\n> CODE\n> ```\n","<blockquote>\n<pre><code>\nCODE\n</code></pre>\n</blockquote>\n",null]
    ["> ```\n> CODE\n> ```\n>","<blockquote>\n<pre><code>\nCODE\n</code></pre>\n\n</blockquote>",null]
    ["> ```\n> CODE\n> ```\n> ","<blockquote>\n<pre><code>\nCODE\n</code></pre>\n\n</blockquote>",null]
    ["> ```\n> CODE\n> ```\n> next line\n> yet another line","<blockquote>\n<pre><code>\nCODE\n</code></pre>\n<p>next line\nyet another line</p>\n</blockquote>",null]
    ["> ```\n> CODE\n> ```","<blockquote>\n<pre><code>\nCODE\n</code></pre>\n</blockquote>",null]
    ["\n# A Headline\n\n> Quote\n> ```\n> CODE\n> ```","\n<h1>A Headline</h1>\n\n<blockquote>\n<p>Quote\n<pre><code>\nCODE\n</code></pre>\n</blockquote>",null]
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



############################################################################################################
unless module.parent?
  # test @, { timeout: 5000, }
  test @[ "xxx" ], { timeout: 1e4, }
  # test @[ "wye with duplex pair"            ]


