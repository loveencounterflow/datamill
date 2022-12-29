
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
CKD                       = require 'chokidar'
{ XE }                    = require './_xemitter'
{ Readable }              = require 'node:stream'


#===========================================================================================================
class Stream extends Readable
  # constructor:            -> @s = new Readable();       undefined
  push:         ( data  ) => super data;              null
  write:        ( data  ) => @push data; @push '\n';  null
  end:          ( data  ) => @push null;              null


#===========================================================================================================
class Datamill_server_base

  #---------------------------------------------------------------------------------------------------------
  with_html_stream: ( ctx, f ) ->
    ctx.response.type = 'html'
    ctx.body          = stream = new Stream()
    f.call @, stream
    stream.end()
    return null

  #---------------------------------------------------------------------------------------------------------
  with_layouted_html_stream: ( ctx, f ) ->
    @with_html_stream ctx, ( stream ) =>
      stream.write row.doc_line_txt for row from @doc.walk_raw_lines [ 'layout', ]
      f.call @, stream
      stream.write row.doc_line_txt for row from @doc.walk_raw_lines [ 'layout', ]
      return null
    return null

  #---------------------------------------------------------------------------------------------------------
  _watch_doc_files: ->
    cfg     = { recursive: true, persistent: true, awaitWriteFinish: { stabilityThreshold: 100, }, }
    watcher = CKD.watch @doc.cfg.home, cfg
    urge '^3534^', "watching @{doc.cfg.home}"
    watcher.on 'add',     ( doc_file_abspath ) => info '^3534^', GUY.trm.reverse 'add',     doc_file_abspath
    watcher.on 'unlink',  ( doc_file_abspath ) => warn '^3534^', GUY.trm.reverse 'unlink',  doc_file_abspath
    watcher.on 'error',   ( error ) => alter  '^3534^', GUY.trm.reverse 'error',  error
    #.......................................................................................................
    watcher.on 'change',  ( doc_file_abspath ) =>
      urge '^3534^', GUY.trm.reverse 'change', doc_file_abspath
      await XE.emit '^maybe-file-changed', { doc_file_abspath, }
      return null
    #.......................................................................................................
    return null


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
    table_url = @router.url 'table',  'sqlite_schema'
    ### TAINT differentiate between documents and files ###
    doc_url   = @router.url 'doc',    'f1'
    files_url = @router.url 'files'
    debug '^32234^', { table_url, doc_url, files_url, }
    ctx.body  = """
      <h1>Datamill</h1>
      <ul>
        <li><a href=#{doc_url}>Document</a></li>
        <li><a href=#{files_url}>Files</a></li>
        <li><a href=#{table_url}>Relations (Tables &amp; Views)</a></li>
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
      rows = @doc.db.all_rows SQL"""select * from #{table_name} order by 1;"""
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
    rows      = @doc.db query, parameters
    return tabulate { rows, table_cfg..., }

  #---------------------------------------------------------------------------------------------------------
  _table_as_html: ( table ) =>
    table_cfg   = @_get_table_cfg table
    query       = SQL"select * from #{@doc.db.sql.I table};"
    rows        = @doc.db query
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

  #---------------------------------------------------------------------------------------------------------
  _r_doc: ( ctx ) =>
    ### TAINT use streaming ###
    ### TAINT use API ###
    ### TAINT allow other values for `doc_file_id` ###
    ### TAINT respect custom table prefix ###
    ctx.response.type   = 'html'
    lines               =  @doc.db.all_first_values SQL"""
      select
          doc_line_txt
        from doc_lines
        where doc_file_id = 'f1'
        order by doc_line_nr;"""
    ctx.body            = lines.join '\n'
    return null

  #---------------------------------------------------------------------------------------------------------
  _r_files: ( ctx ) =>
    ### TAINT use layout ###
    ### TAINT use API ###
    ### TAINT respect custom table prefix ###
    @with_layouted_html_stream ctx, ({ push, write, }) ->
      debug '^_rfiles@397324^', @types.type_of ctx.body
      write HDML.pair 'h1', HDML.text "Datamill"
      write HDML.pair 'h2', HDML.text "Files"
      write HDML.open 'ul'
      for file from @doc.db SQL"""select * from doc_files order by 1, 2;"""
        href = @router.url 'file', file.doc_file_id
        write HDML.pair 'li', HDML.pair 'a', { href, }, HDML.text file.doc_file_path
      write HDML.close 'ul'
    return null

  #---------------------------------------------------------------------------------------------------------
  _r_file: ( ctx ) =>
    ### TAINT use streaming ###
    ### TAINT use layout ###
    ### TAINT use API ###
    ### TAINT respect custom table prefix ###
    ctx.response.type   = 'text/plain'
    ### thx to https://stackoverflow.com/a/51616217/7568091 ###
    rsp                 = ctx.body = new Stream()
    rsp.push '-------------------------------------\n'
    #.......................................................................................................
    debug '^35324^', { doc_file_id: ctx.params.dfid, }
    for doc_line_txt from @doc.db.first_values SQL"""
      select
          doc_line_txt
        from doc_lines
        where doc_file_id = $doc_file_id
        order by doc_file_id, doc_line_nr;""", { doc_file_id: ctx.params.dfid, }
      rsp.push doc_line_txt + '\n'
    #.......................................................................................................
    rsp.push '-------------------------------------\n'
    rsp.push null # indicates end of the stream
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
    GUY.props.hide @, 'doc', @cfg.doc; delete @cfg.doc
    @cfg        = Object.freeze @cfg
    #.......................................................................................................
    GUY.props.hide @, 'app',    new Koa()
    GUY.props.hide @, 'router', new Router()
    #.......................................................................................................
    @_watch_doc_files()
    return undefined


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
    #.......................................................................................................
    @router.get   'home',           '/',              @_r_home
    @router.get   'tables',         '/tables',        @_r_tables
    @router.get   'table',          '/table/:rel',    @_r_table
    @router.get   'files',          '/files',         @_r_files
    @router.get   'file',           '/file/:dfid',    @_r_file
    ### TAINT differentiate between 'documents' and 'files' ###
    # @router.get   'docs',           '/docs',          @_r_docs
    @router.get   'doc',            '/doc/:dfid',     @_r_doc
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




