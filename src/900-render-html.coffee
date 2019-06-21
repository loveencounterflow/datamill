




'use strict'

############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DATAMILL/MAIN'
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
MIRAGE                    = require 'mkts-mirage'
VNR                       = require './vnr'
#...........................................................................................................
PD                        = require 'pipedreams'
{ $
  $watch
  $async
  select
  stamp }                 = PD
#...........................................................................................................
@types                    = require './types'
{ isa
  validate
  cast
  first_of
  last_of
  size_of
  type_of }               = @types
#...........................................................................................................
H                         = require './helpers'
{ cwd_abspath
  cwd_relpath
  here_abspath
  project_abspath }       = H
#...........................................................................................................
DM                        = require '..'

# #-----------------------------------------------------------------------------------------------------------
# @$decorations = ( S ) -> $ { first, last, }, ( d, send ) =>
#   if d is first
#     send H.fresh_datom '^html', { text: '<html><body>', ref: 'rdh/deco-1', $vnr: [ -Infinity, ], }
#   if d is last
#     send H.fresh_datom '^html', { text: '</body></html>', ref: 'rdh/deco-2', $vnr: [ Infinity, ], }
#   else
#     send d
#   return null

#-----------------------------------------------------------------------------------------------------------
@$headings = ( S ) ->
  pipeline = []
  pipeline.push H.leapfrog_stamped PD.lookaround $ ( d3, send ) =>
    [ prv, d, nxt, ] = d3
    return unless ( select prv, '<h' ) and ( select d, '^mktscript' ) and ( select nxt, '>h' )
    $vnr    = VNR.deepen d.$vnr
    tagname = "h#{prv.level}"
    text    = "<#{tagname}>#{d.text}</#{tagname}>"
    send H.fresh_datom '^html', { text, ref: 'rdh/h', $vnr, }
    send stamp prv
    send stamp d
    send stamp nxt
  #.........................................................................................................
  ### Make sure ordering is preserved for downstream transforms: ###
  pipeline.push H.$resume_from_db S, { realm: 'html', }
  return PD.pull pipeline...

#-----------------------------------------------------------------------------------------------------------
@$codeblocks = ( S ) ->
  return H.leapfrog_stamped PD.lookaround $ ( d3, send ) =>
    [ prv, d, nxt, ] = d3
    return send d unless select d, '^literal'
    if select prv,  '<codeblock'
      $vnr  = VNR.deepen prv.$vnr
      text  = "<pre><code>"
      send H.fresh_datom '^html', { text, ref: 'rdh/cdb1', $vnr, }
      send stamp prv
    if select nxt,  '>codeblock'
      $vnr  = VNR.deepen nxt.$vnr
      text  = "</code></pre>"
      send H.fresh_datom '^html', { text, ref: 'rdh/cdb2', $vnr, }
      send stamp nxt
    $vnr  = VNR.deepen d.$vnr
    send H.fresh_datom '^html', { text: d.text, ref: 'rdh/cdb3', $vnr, }
    send stamp d

#-----------------------------------------------------------------------------------------------------------
@$blocks_with_mktscript = ( S ) ->
  key_registry    = H.get_key_registry S
  is_block        = ( d ) -> key_registry[ d.key ]?.is_block
  pipeline        = []
  pipeline.push PD.lookaround $ ( d3, send ) =>
    [ prv, d, nxt, ] = d3
    return send d unless select d, '^mktscript'
    text = d.text
    if is_block prv
      tagname = prv.key[ 1 .. ]
      ### TAINT use proper HTML generation ###
      text    = "<#{tagname}>#{text}"
      send stamp prv
    if is_block nxt
      tagname = nxt.key[ 1 .. ]
      text    = "#{text}</#{tagname}>"
      send stamp nxt
    $vnr = VNR.deepen d.$vnr
    send H.fresh_datom '^html', { text, ref: 'rdh/bwm', $vnr, }
    send stamp d
    return null
  #.........................................................................................................
  ### Make sure ordering is preserved for downstream transforms: ###
  pipeline.push H.$resume_from_db S, { realm: 'html', }
  return PD.pull pipeline...

# #-----------------------------------------------------------------------------------------------------------
# @$other_blocks = ( S ) ->
#   key_registry    = H.get_key_registry S
#   is_block        = ( d ) -> key_registry[ d.key ]?.is_block
#   return H.resume_from_db S, { realm: 'html', }, $ ( d, send ) =>
#     return send d unless ( select d, '<>' ) and ( is_block d )
#     debug 'µ29882', '$other_blocks', jr d
#     tagname = d.key[ 1 .. ]
#     ### TAINT use proper HTML generation ###
#     if select d, '<' then text = "<#{tagname}>"
#     else                  text = "</#{tagname}>"
#     $vnr = VNR.deepen d.$vnr
#     send H.fresh_datom '^html', { text: text, ref: 'rdh/ob', $vnr, }
#     send stamp d
#     return null

#-----------------------------------------------------------------------------------------------------------
# @$blank = ( S ) -> $ ( d, send ) =>
@$blank = ( S ) -> H.resume_from_db_after S, { realm: 'html', }, $ ( d, send ) =>
  return send d unless select d, '^blank'
  $vnr = VNR.deepen d.$vnr
  send stamp d
  if ( linecount = ( d.linecount ? 0 ) - 1 ) > -1
    text = '\n'.repeat linecount
    send H.fresh_datom '^html', { text, ref: 'rdh/blnk', $vnr, }
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
preamble = """
  <style>
    * { padding: 4px; outline: 2px dotted green; }
    </style>
  """

#-----------------------------------------------------------------------------------------------------------
### TAINT refactor to PipeStreams ###
PD.$send_as_first = ( x ) -> $ { first, }, ( d, send ) -> send if d is first then x else d
PD.$send_as_last  = ( x ) -> $ { last,  }, ( d, send ) -> send if d is last  then x else d

#-----------------------------------------------------------------------------------------------------------
@$write_to_file = ( S ) =>
  pipeline  = []
  pipeline.push H.$resume_from_db S, { realm: 'html', }
  pipeline.push PD.$filter ( d ) -> select d, '^html'
  pipeline.push $ ( d, send ) -> send d.text + '\n'
  pipeline.push PD.$send_as_first preamble
  pipeline.push PD.write_to_file '/tmp/datamill.html'
  return PD.$tee PD.pull pipeline...


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@settings =
  from_realm:   'html'
  to_realm:     'html'

#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  H.register_key    S, '^html', { is_block: false, }
  H.register_realm  S, @settings.to_realm
  H.copy_realm      S, 'input', 'html'
  pipeline = []
  pipeline.push @$headings                  S
  pipeline.push @$codeblocks                S
  pipeline.push @$blocks_with_mktscript     S
  pipeline.push @$blank                     S
  pipeline.push H.$set_realm_where_missing  S, @settings.to_realm
  pipeline.push @$write_to_file             S
  return PD.pull pipeline...





