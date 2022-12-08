
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


#===========================================================================================================
class @Datamill_server

  #---------------------------------------------------------------------------------------------------------
  constructor: ( cfg ) ->
    # super()
    GUY.props.hide @, 'types', get_server_types()
    @cfg        = @types.create.datamill_server_cfg cfg
    GUY.props.hide @, 'db', @cfg.db; delete cfg.db
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

  #---------------------------------------------------------------------------------------------------------
  start: => new Promise ( resolve, reject ) =>
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
  _create_app: =>
    ###
    `_r_*`: managed by router
    `_s_*`: managed by server
    ###
    @app.use                                          @_s_log
    @app.use                                          @_s_layout
    #.......................................................................................................
    @router.get   'home',           '/',              @_r_home
    @router.get   'relations',      '/relations',     @_r_relations
    # @router.get   'trends',         '/trends',        @_r_trends
    # @router.get   'layout-demo',    '/layout-demo',   @_r_layout_demo
    @router.get   'table_by_name',  '/table/:table',  @_r_table_by_name
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
    ctx.body = """
      <h1>Datamill</h1>
      <ul>
        <li><a href=relations>Relations (Tables &amp; Views)</a></li>
        </ul>
      """
    # help "^datamill/server@7^", ctx.router.url 'home', { query: { foo: 'bar', }, }
    return null

  #---------------------------------------------------------------------------------------------------------
  _r_relations: ( ctx ) =>
    ### TAINT generate from DB or load from external file ###
    # public_table_name   = ctx.params.table
    content = []
    content.push HDML.open 'table'
    content.push HDML.open 'tr'
    content.push HDML.pair 'th', HDML.text 'type'
    content.push HDML.pair 'th', HDML.text 'name'
    content.push HDML.pair 'th', HDML.text 'SQL'
    content.push HDML.close 'tr'
    for row from @db SQL"""select * from sqlite_schema order by name;"""
      content.push HDML.open 'tr'
      content.push HDML.pair 'td', HDML.text row.type
      content.push HDML.pair 'td', HDML.text row.name
      content.push HDML.pair 'td', HDML.pair 'pre', HDML.text row.sql ? './.'
    content.push HDML.close 'table'
    ctx.body = content.join '\n'
    rows = @db.all_rows SQL"""select * from sqlite_schema order by name;"""
    ctx.body += '<hr>'
    ctx.body += tabulate { rows, ( @_get_table_cfg 'relations' )..., }
    return null

  # #---------------------------------------------------------------------------------------------------------
  # _r_trends: ( ctx ) =>
  #   ### TAINT iterate or use stream ###
  #   ### TAINT chart is per-DSK but trends table is global ###
  #   R                 = []
  #   trends_table_name = @db._get_table_name 'trends'
  #   R.push @_get_dsk_form ctx.query.dsk ? ''
  #   #.......................................................................................................
  #   if ctx.query.dsk in [ '', undefined, ]
  #     for { dsk, scraper, } from @hub.scrapers._XXX_walk_scrapers()
  #       R.push scraper._XXX_get_details_chart { dsk, }
  #       # R.push scraper._XXX_get_details_table { dsk, }
  #     R.push @_table_as_html trends_table_name
  #   else if ( scraper = @hub.scrapers._scraper_from_dsk ctx.query.dsk, null )?
  #     table_name_i  = @db.sql.I trends_table_name
  #     query         = SQL"select * from #{table_name_i} where dsk = $dsk order by rank;"
  #     parameters    = { dsk: ctx.query.dsk, }
  #     R.push scraper._XXX_get_details_chart { dsk: ctx.query.dsk, }
  #     R.push @_query_as_html trends_table_name, query, parameters
  #   else
  #     ### TAINT use correct error handling ###
  #     R.push HDML.pair 'div.error', HDML.text "no such data source: #{rpr ctx.query.dsk}"
  #   #.......................................................................................................
  #   ctx.response.type   = 'html'
  #   ctx.body            = R.join '\n'
  #   return null

  #---------------------------------------------------------------------------------------------------------
  _r_table_by_name: ( ctx ) =>
    public_table_name   = ctx.params.table
    table               = @db._get_table_name public_table_name
    R                   = []
    R.push HDML.pair 'h1', HDML.text public_table_name
    R.push @_table_as_html table
    #.......................................................................................................
    ctx.response.type   = 'html'
    ctx.body            =  R.join '\n'
    return null

  #---------------------------------------------------------------------------------------------------------
  _get_dsk_form: ( selected = '' ) =>
    R                   = []
    #.......................................................................................................
    R.push HDML.open  'nav'
    R.push HDML.open  'form', { method: 'GET', action: '/trends', }
    R.push HDML.pair  'label', { for: 'dsk', }, "Data Source:"
    R.push HDML.open  'select', { name: 'dsk', id: 'dsk', onchange: "this.form.submit();", }
    R.push HDML.pair  'option', { value: '', }, HDML.text "Select a Data Source"
    for { dsk, url, } from @db._walk_datasources()
      label           = "#{dsk} (#{url})"
      atrs            = { value: dsk, }
      atrs.selected   = 'true' if selected is dsk
      R.push HDML.pair  'option', atrs, HDML.text label
    R.push HDML.close 'select'
    R.push HDML.pair 'button', { type: 'submit', }, HDML.text "submit"
    R.push HDML.close 'form'
    R.push HDML.close 'nav'
    return R.join '\n'

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
    @table_cfgs[ 'relations' ] =
      fields:
        name:
          hide:     false
        type:
          hide:     false
        rootpage:
          hide:     true
        sql:
          title:  "SQL"
          inner_html:   ( d ) =>
    #.......................................................................................................
    # @table_cfgs[ 'trends' ] =
    #   fields:
    #     #...................................................................................................
    #     dsk:
    #       hide: true
    #     #...................................................................................................
    #     sid_min:
    #       hide: true
    #     sid_max:
    #       title:  "SIDs"
    #       inner_html: ( d ) =>
    #         { sid_min
    #           sid_max } = d.row
    #         return sid_min if sid_min is sid_max
    #         return "#{sid_min}—#{sid_max}"
    #     #...................................................................................................
    #     ts:
    #       inner_html: ( d ) => @db.dt_format d.value, 'YYYY-MM-DD HH:mm UTC'
    #     #...................................................................................................
    #     raw_trend:
    #       title:  "Trend"
    #       outer_html:   ({ value: raw_trend }) =>
    #         return HDML.pair 'td.trend.sparkline', { 'data-trend': raw_trend, }
    #     #...................................................................................................
    #     details:
    #       inner_html:   ( d ) =>
    #         try row = JSON.parse d.value catch error
    #           return HDML.pair 'div.error', HDML.text error.message
    #         cfg =
    #           row:        row
    #           fields:
    #             title:
    #               title:      "Title"
    #               inner_html: ({ value: title, row, }) =>
    #                 return HDML.pair 'a', { href: row.title_url, }, HDML.text title
    #             title_url:
    #               hide: true
    #             article:
    #               title:      "Article"
    #               inner_html: ({ value: title, row, }) =>
    #                 return Symbol.for 'hide' unless title?
    #                 return Symbol.for 'hide' unless row.article_url?
    #                 return HDML.pair 'a', { href: row.article_url, }, HDML.text title
    #             article_url:
    #               hide: true
    #         return summarize cfg
            return summarize cfg
    return null

  # #---------------------------------------------------------------------------------------------------------
  # _r_layout_demo: ( ctx ) =>
  #   R                   = []
  #   #.......................................................................................................
  #   R.push HDML.open  'nav'
  #   R.push HDML.open  'menu'
  #   R.push HDML.pair  'li', HDML.pair 'a', { href: '#', }, HDML.text "one"
  #   R.push HDML.pair  'li', HDML.pair 'a', { href: '#', }, HDML.text "two"
  #   R.push HDML.pair  'li', HDML.pair 'a', { href: '#', }, HDML.text "three"
  #   R.push HDML.close 'menu'
  #   R.push HDML.close 'nav'
  #   #.......................................................................................................
  #   R.push HDML.pair  'header', HDML.text "header"
  #   #.......................................................................................................
  #   R.push HDML.open  'main'
  #   R.push HDML.open  'article'
  #   R.push HDML.text  "article"
  #   R.push HDML.close 'article'
  #   R.push HDML.close 'main'
  #   #.......................................................................................................
  #   R.push HDML.pair  'footer', HDML.text "footer"
  #   #.......................................................................................................
  #   ctx.response.type   = 'html'
  #   ctx.body            =  R.join '\n'
  #   return null
