
'use strict'


############################################################################################################
GUY                       = require 'guy'
{ alert
  debug
  help
  info
  plain
  praise
  urge
  warn
  whisper }               = GUY.trm.get_loggers 'DATAMILL/SERVER'
{ rpr
  inspect
  echo
  log     }               = GUY.trm
types                     = new ( require 'intertype' ).Intertype()
{ isa
  type_of }               = types
#...........................................................................................................
FS                        = require 'fs'
PATH                      = require 'path'
HTTP                      = require 'http'
Koa                       = require 'koa'
Router                    = require '@koa/router'
{ Server: Socket_server } = require 'socket.io'
file_server               = require 'koa-files'
mount                     = require 'koa-mount'
{ HDML }                  = require 'hdml'
{ SQL }                   = ( require 'dbay' ).DBay
{ tabulate
  summarize }             = require 'dbay-tabulator'
{ get_base_types
  get_server_types }      = require './types'
NODEXH                    = require '../../nodexh'


#===========================================================================================================
class Datamill_server_base

  #=========================================================================================================
  #
  #---------------------------------------------------------------------------------------------------------
  _s_log: ( ctx, next ) =>
    await next()
    querystring   = if ctx.querystring?.length > 1 then "?#{ctx.querystring}" else ''
    # help "^datamill/server@7^", { method, url, originalUrl, origin, href, path, query, querystring, host, hostname, protocol, }
    color = if ctx.status < 400 then 'lime' else 'red'
    line  = "#{ctx.method} #{ctx.origin}#{ctx.path}#{querystring} -> #{ctx.status} #{ctx.message}"
    echo ( GUY.trm.grey "^datamill/server@7^" ), ( GUY.trm[ color ] line )
    # warn "^datamill/server@7^", "#{ctx.status} #{ctx.message}"
    return null

  #---------------------------------------------------------------------------------------------------------
  _s_layout: ( ctx, next ) =>
    await next()
    if ( ctx.type is 'text/html' ) and ( not ctx.body?.startswith? "<!DOCTYPE html>" )
      ctx.body = @cfg.layout.top + ctx.body + @cfg.layout.bottom
    return null

  #---------------------------------------------------------------------------------------------------------
  _s_default: ( ctx ) =>
    ctx.response.status = 404
    ctx.response.type   = 'html'
    ctx.body            = "<h3>Datamill / 404 / Not Found</h3>"
    # ctx.throw 404, "no content under #{ctx.url}"
    # ( ctx.state.greetings ?= [] ).push "helo from content handler"
    return null

  #---------------------------------------------------------------------------------------------------------
  _r_home: ( ctx ) =>
    ### TAINT generate from DB or load from external file ###
    relation = @router.url 'table', 'sqlite_schema'
    debug '^32234^', { relation, }
    ctx.body = """
      <h1>Datamill</h1>
      <ul>
        <li><a href=#{relation}>Relations (Tables &amp; Views)</a></li>
        </ul>
      """
    # help "^datamill/server@7^", ctx.router.url 'home', { query: { foo: 'bar', }, }
    return null

  #---------------------------------------------------------------------------------------------------------
  _r_tables: ( ctx ) => @_table_by_name ctx, 'sqlite_schema'

  #---------------------------------------------------------------------------------------------------------
  _r_table: ( ctx ) =>
    table_name  = ctx.params.rel ? 'sqlite_schema'
    table_name  = 'sqlite_schema' if table_name is ''
    return @_table_by_name ctx, table_name
    return null

  #---------------------------------------------------------------------------------------------------------
  _table_by_name: ( ctx, table_name ) =>
    R                   = []
    R.push HDML.pair 'h1', HDML.text "Table #{table_name}"
    #.......................................................................................................
    ### TAINT use proper interpolation or API ###
    try
      rows = @db.all_rows SQL"""select * from #{table_name} order by 1;"""
    catch error
      ctx.response.status = 500
      ctx.response.type   = 'text/plain'
      ctx.body            = error.message
      return null
    #.......................................................................................................
    unless ( table_cfg = @_get_table_cfg table_name )?
      # ctx.response.status = 404
      # ctx.response.type   = 'text/plain'
      # ctx.body            = "no such table: #{table_name}"
      # return null
      table_cfg = null
    #.......................................................................................................
    R                   = R.concat tabulate { rows, table_cfg..., }
    ctx.response.type   = 'html'
    ctx.body            =  R.join '\n'
    return null

  #---------------------------------------------------------------------------------------------------------
  _query_as_html: ( table, query, parameters ) =>
    table_cfg = @_get_table_cfg table
    rows      = @db query, parameters
    return tabulate { rows, table_cfg..., }

  #---------------------------------------------------------------------------------------------------------
  _table_as_html: ( table ) =>
    table_cfg   = @_get_table_cfg table
    query       = SQL"select * from #{@db.sql.I table};"
    rows        = @db query
    return tabulate { rows, table_cfg..., }

  #---------------------------------------------------------------------------------------------------------
  _get_table_cfg: ( table ) =>
    @_set_table_cfgs() unless @table_cfgs?
    return @table_cfgs[ table ] ? null

  #---------------------------------------------------------------------------------------------------------
  _set_table_cfgs: =>
    GUY.props.hide @, 'table_cfgs', {}
    #.......................................................................................................
    @table_cfgs[ 'sqlite_schema' ] =
      fields:
        name:
          hide:     false
          inner_html: ( d ) =>
            href = @router.url 'table', d.value
            debug '^inner_html@234^', ( rpr d.value ), ( rpr href )
            return HDML.pair 'a', { href, }, HDML.text d.value ? './.'
        table_name:
          hide:     true
        type:
          hide:     false
        rootpage:
          hide:     true
        sql:
          title:  "SQL"
          inner_html: ( d ) => HDML.pair 'pre', HDML.text d.value ? './.'
    #.......................................................................................................
    return null

  #=========================================================================================================
  # ERROR HANDLING
  #---------------------------------------------------------------------------------------------------------
  $error_handler: -> ( error, ctx ) =>
    if ( url = ctx?.request.url )?
      prefix = "When trying to retrieve #{rpr url}, an "
    else
      prefix = "An "
    message = prefix + "error with message #{rpr error.message ? "UNKNOWN"} was encountered"
    warn '^3298572^', error
    warn GUY.trm.reverse '^3298572^', message
    debug '^323423^', await NODEXH._exit_handler error
    return null


#===========================================================================================================
class Datamill_server extends Datamill_server_base

  #=========================================================================================================
  # CONSTRUCTION
  #---------------------------------------------------------------------------------------------------------
  constructor: ( cfg ) ->
    super()
    GUY.props.hide @, 'types', get_server_types()
    @cfg        = @types.create.datamill_server_cfg cfg
    GUY.props.hide @, 'db', @cfg.db; delete @cfg.db
    @_add_layout()
    @cfg        = GUY.lft.freeze @cfg
    #.......................................................................................................
    GUY.props.hide @, 'app',    new Koa()
    GUY.props.hide @, 'router', new Router()
    #.......................................................................................................
    return undefined

  #---------------------------------------------------------------------------------------------------------
  _add_layout: ->
    @cfg.layout ?= {}
    return null if @cfg.layout.top? and @cfg.layout.bottom?
    path    = PATH.resolve PATH.join __dirname, '../assets/layout.html'
    layout  = FS.readFileSync path, { encoding: 'utf-8', }
    [ layout_top
      layout_bottom   ] = layout.split '<%content%>'
    @cfg.layout.top    ?= layout_top
    @cfg.layout.bottom ?= layout_bottom
    return null


  #=========================================================================================================
  # RUN SERVER
  #---------------------------------------------------------------------------------------------------------
  start: -> new Promise ( resolve, reject ) =>
    { host
      port  } = @cfg
    @_create_app()
    #.......................................................................................................
    GUY.props.hide @, 'http_server',  HTTP.createServer @app.callback()
    GUY.props.hide @, 'io',           new Socket_server @http_server
    #.......................................................................................................
    @io.on 'connection', ( socket ) =>
      help "^datamill/server@8^ user connected to socket"
      socket.on 'message', ( P... ) -> info '^datamill/server@8^', P
      return null
    #.......................................................................................................
    @io.on 'disconnect', ( socket ) =>
      help "^datamill/server@8^ user disconnected from socket"
      return null
    #.......................................................................................................
    @http_server.listen { host, port, }, ->
      debug "^datamill/server@9^ listening on #{host}:#{port}"
      resolve { host, port, }
    #.......................................................................................................
    return null

  #---------------------------------------------------------------------------------------------------------
  _create_app: ->
    ###
    `_r_*`: managed by router
    `_s_*`: managed by server
    ###
    @app.use                                          @_s_log
    @app.use                                          @_s_layout
    #.......................................................................................................
    @router.get   'home',           '/',              @_r_home
    @router.get   'tables',         '/tables',        @_r_tables
    @router.get   'table',          '/table/:rel',    @_r_table
    # @router.get   'trends',         '/trends',        @_r_trends
    # @router.get   'layout-demo',    '/layout-demo',   @_r_layout_demo
    # @router.get   'table_by_name',  '/table/:table',  @_r_table_by_name
    #.......................................................................................................
    @app.use @router.routes()
    #.......................................................................................................
    ### thx to https://stackoverflow.com/a/66377342/7568091 ###
    debug '^4345^', @cfg.paths.public
    debug '^4345^', @cfg.file_server
    # @app.use mount '/favicon.ico', file_server @cfg.paths.favicon, @cfg.file_server
    @app.use mount '/public', file_server @cfg.paths.public, @cfg.file_server
    @app.use mount '/src',    file_server @cfg.paths.src,    @cfg.file_server
    #.......................................................................................................
    @app.use @_s_default
    @app.use @router.allowedMethods()
    #.......................................................................................................
    @app.on 'error', @$error_handler()
    return null

############################################################################################################
module.exports = { Datamill_server_base, Datamill_server, }




