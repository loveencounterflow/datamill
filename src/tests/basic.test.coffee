

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
@[ "xxx" ] = ( T, done ) ->
  probes_and_matchers = []
    # ["A *short* **demonstration** of `MKTScript`.",2,null]
    # ["A *short **demonstration*** of `MKTScript`.",2,null]
    # ]
  #.........................................................................................................
  await do => new Promise ( resolve ) =>
    text      = """
      a short text
      """
    settings  = { text, }
    datamill  = await DM.create settings
    await DM.parse_document datamill
    pipeline  = []
    pipeline.push H.new_db_source datamill, 'html'
    pipeline.push PD.$show()
    pipeline.push PD.$drain -> resolve()
    PD.pull pipeline...

  # await H.show_overview   datamill
  # await H.show_html       datamill
  # for [ probe, matcher, error, ] in probes_and_matchers
  #   await T.perform probe, matcher, error, -> new Promise ( resolve ) ->
  #     resolve null
  #.........................................................................................................
  defer -> done()
  return null



############################################################################################################
unless module.parent?
  # test @, { timeout: 5000, }
  test @[ "xxx" ]
  # test @[ "wye with duplex pair"            ]

