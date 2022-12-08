(function() {
  'use strict';
  var FS, GUY, HDML, HTTP, Koa, PATH, Router, SQL, Socket_server, alert, debug, echo, file_server, get_base_types, get_server_types, help, info, inspect, isa, log, mount, plain, praise, rpr, summarize, tabulate, type_of, types, urge, warn, whisper;

  //###########################################################################################################
  GUY = require('guy');

  ({alert, debug, help, info, plain, praise, urge, warn, whisper} = GUY.trm.get_loggers('DATAMILL/SERVER'));

  ({rpr, inspect, echo, log} = GUY.trm);

  types = new (require('intertype')).Intertype();

  ({isa, type_of} = types);

  //...........................................................................................................
  FS = require('fs');

  PATH = require('path');

  HTTP = require('http');

  Koa = require('koa');

  Router = require('@koa/router');

  ({
    Server: Socket_server
  } = require('socket.io'));

  file_server = require('koa-files');

  mount = require('koa-mount');

  ({HDML} = require('hdml'));

  ({SQL} = (require('dbay')).DBay);

  ({tabulate, summarize} = require('dbay-tabulator'));

  ({get_base_types, get_server_types} = require('./types'));

  //===========================================================================================================
  this.Datamill_server = class Datamill_server {
    //---------------------------------------------------------------------------------------------------------
    constructor(cfg) {
      //---------------------------------------------------------------------------------------------------------
      this.start = this.start.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._create_app = this._create_app.bind(this);
      //=========================================================================================================

      //---------------------------------------------------------------------------------------------------------
      this._s_log = this._s_log.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._s_layout = this._s_layout.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._s_default = this._s_default.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._r_home = this._r_home.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._r_relation = this._r_relation.bind(this);
      // #---------------------------------------------------------------------------------------------------------
      // _r_trends: ( ctx ) =>
      //   ### TAINT iterate or use stream ###
      //   ### TAINT chart is per-DSK but trends table is global ###
      //   R                 = []
      //   trends_table_name = @db._get_table_name 'trends'
      //   R.push @_get_dsk_form ctx.query.dsk ? ''
      //   #.......................................................................................................
      //   if ctx.query.dsk in [ '', undefined, ]
      //     for { dsk, scraper, } from @hub.scrapers._XXX_walk_scrapers()
      //       R.push scraper._XXX_get_details_chart { dsk, }
      //       # R.push scraper._XXX_get_details_table { dsk, }
      //     R.push @_table_as_html trends_table_name
      //   else if ( scraper = @hub.scrapers._scraper_from_dsk ctx.query.dsk, null )?
      //     table_name_i  = @db.sql.I trends_table_name
      //     query         = SQL"select * from #{table_name_i} where dsk = $dsk order by rank;"
      //     parameters    = { dsk: ctx.query.dsk, }
      //     R.push scraper._XXX_get_details_chart { dsk: ctx.query.dsk, }
      //     R.push @_query_as_html trends_table_name, query, parameters
      //   else
      //     ### TAINT use correct error handling ###
      //     R.push HDML.pair 'div.error', HDML.text "no such data source: #{rpr ctx.query.dsk}"
      //   #.......................................................................................................
      //   ctx.response.type   = 'html'
      //   ctx.body            = R.join '\n'
      //   return null

      //---------------------------------------------------------------------------------------------------------
      this._r_table_by_name = this._r_table_by_name.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._get_dsk_form = this._get_dsk_form.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._query_as_html = this._query_as_html.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._table_as_html = this._table_as_html.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._get_table_cfg = this._get_table_cfg.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._set_table_cfgs = this._set_table_cfgs.bind(this);
      // super()
      GUY.props.hide(this, 'types', get_server_types());
      this.cfg = this.types.create.datamill_server_cfg(cfg);
      GUY.props.hide(this, 'db', this.cfg.db);
      delete cfg.db;
      this._add_layout();
      this.cfg = GUY.lft.freeze(this.cfg);
      //.......................................................................................................
      GUY.props.hide(this, 'app', new Koa());
      GUY.props.hide(this, 'router', new Router());
      //.......................................................................................................
      return void 0;
    }

    //---------------------------------------------------------------------------------------------------------
    _add_layout() {
      var base, base1, base2, layout, layout_bottom, layout_top, path;
      if ((base = this.cfg).layout == null) {
        base.layout = {};
      }
      if ((this.cfg.layout.top != null) && (this.cfg.layout.bottom != null)) {
        return null;
      }
      path = PATH.resolve(PATH.join(__dirname, '../assets/layout.html'));
      layout = FS.readFileSync(path, {
        encoding: 'utf-8'
      });
      [layout_top, layout_bottom] = layout.split('<%content%>');
      if ((base1 = this.cfg.layout).top == null) {
        base1.top = layout_top;
      }
      if ((base2 = this.cfg.layout).bottom == null) {
        base2.bottom = layout_bottom;
      }
      return null;
    }

    start() {
      return new Promise((resolve, reject) => {
        var host, port;
        ({host, port} = this.cfg);
        this._create_app();
        //.......................................................................................................
        GUY.props.hide(this, 'http_server', HTTP.createServer(this.app.callback()));
        GUY.props.hide(this, 'io', new Socket_server(this.http_server));
        //.......................................................................................................
        this.io.on('connection', (socket) => {
          help("^datamill/server@8^ user connected to socket");
          socket.on('message', function(...P) {
            return info('^datamill/server@8^', P);
          });
          return null;
        });
        //.......................................................................................................
        this.io.on('disconnect', (socket) => {
          help("^datamill/server@8^ user disconnected from socket");
          return null;
        });
        //.......................................................................................................
        this.http_server.listen({host, port}, function() {
          debug(`^datamill/server@9^ listening on ${host}:${port}`);
          return resolve({host, port});
        });
        //.......................................................................................................
        return null;
      });
    }

    _create_app() {
      /*
      `_r_*`: managed by router
      `_s_*`: managed by server
      */
      this.app.use(this._s_log);
      this.app.use(this._s_layout);
      //.......................................................................................................
      this.router.get('home', '/', this._r_home);
      this.router.get('relation', '/relation/:rel', this._r_relation);
      // @router.get   'trends',         '/trends',        @_r_trends
      // @router.get   'layout-demo',    '/layout-demo',   @_r_layout_demo
      this.router.get('table_by_name', '/table/:table', this._r_table_by_name);
      //.......................................................................................................
      this.app.use(this.router.routes());
      //.......................................................................................................
      /* thx to https://stackoverflow.com/a/66377342/7568091 */
      debug('^4345^', this.cfg.paths.public);
      debug('^4345^', this.cfg.file_server);
      // @app.use mount '/favicon.ico', file_server @cfg.paths.favicon, @cfg.file_server
      this.app.use(mount('/public', file_server(this.cfg.paths.public, this.cfg.file_server)));
      this.app.use(mount('/src', file_server(this.cfg.paths.src, this.cfg.file_server)));
      //.......................................................................................................
      this.app.use(this._s_default);
      this.app.use(this.router.allowedMethods());
      return null;
    }

    async _s_log(ctx, next) {
      var color, line, querystring, ref;
      await next();
      querystring = ((ref = ctx.querystring) != null ? ref.length : void 0) > 1 ? `?${ctx.querystring}` : '';
      // help "^datamill/server@7^", { method, url, originalUrl, origin, href, path, query, querystring, host, hostname, protocol, }
      color = ctx.status < 400 ? 'lime' : 'red';
      line = `${ctx.method} ${ctx.origin}${ctx.path}${querystring} -> ${ctx.status} ${ctx.message}`;
      echo(GUY.trm.grey("^datamill/server@7^"), GUY.trm[color](line));
      // warn "^datamill/server@7^", "#{ctx.status} #{ctx.message}"
      return null;
    }

    async _s_layout(ctx, next) {
      var ref;
      await next();
      if ((ctx.type === 'text/html') && (!((ref = ctx.body) != null ? typeof ref.startswith === "function" ? ref.startswith("<!DOCTYPE html>") : void 0 : void 0))) {
        ctx.body = this.cfg.layout.top + ctx.body + this.cfg.layout.bottom;
      }
      return null;
    }

    _s_default(ctx) {
      ctx.response.status = 404;
      ctx.response.type = 'html';
      ctx.body = "<h3>Datamill / 404 / Not Found</h3>";
      // ctx.throw 404, "no content under #{ctx.url}"
      // ( ctx.state.greetings ?= [] ).push "helo from content handler"
      return null;
    }

    _r_home(ctx) {
      /* TAINT generate from DB or load from external file */
      var relation;
      relation = this.router.url('relation', 'sqlite_schema');
      debug('^32234^', {relation});
      ctx.body = `<h1>Datamill</h1>
<ul>
  <li><a href=${relation}>Relations (Tables &amp; Views)</a></li>
  </ul>`;
      // help "^datamill/server@7^", ctx.router.url 'home', { query: { foo: 'bar', }, }
      return null;
    }

    _r_relation(ctx) {
      /* TAINT use proper interpolation or API */
      /* TAINT use proper error handling in case table_name not found */
      var ref, rows, table_cfg, table_name;
      table_name = (ref = ctx.params.rel) != null ? ref : 'sqlite_schema';
      if (table_name === '') {
        table_name = 'sqlite_schema';
      }
      rows = this.db.all_rows(SQL`select * from ${table_name} order by 1;`);
      table_cfg = this._get_table_cfg(table_name);
      ctx.body = tabulate({rows, ...table_cfg});
      return null;
    }

    _r_table_by_name(ctx) {
      var R, public_table_name, table;
      public_table_name = ctx.params.table;
      table = this.db._get_table_name(public_table_name);
      R = [];
      R.push(HDML.pair('h1', HDML.text(public_table_name)));
      R.push(this._table_as_html(table));
      //.......................................................................................................
      ctx.response.type = 'html';
      ctx.body = R.join('\n');
      return null;
    }

    _get_dsk_form(selected = '') {
      var R, atrs, dsk, label, ref, url, x;
      R = [];
      //.......................................................................................................
      R.push(HDML.open('nav'));
      R.push(HDML.open('form', {
        method: 'GET',
        action: '/trends'
      }));
      R.push(HDML.pair('label', {
        for: 'dsk'
      }, "Data Source:"));
      R.push(HDML.open('select', {
        name: 'dsk',
        id: 'dsk',
        onchange: "this.form.submit();"
      }));
      R.push(HDML.pair('option', {
        value: ''
      }, HDML.text("Select a Data Source")));
      ref = this.db._walk_datasources();
      for (x of ref) {
        ({dsk, url} = x);
        label = `${dsk} (${url})`;
        atrs = {
          value: dsk
        };
        if (selected === dsk) {
          atrs.selected = 'true';
        }
        R.push(HDML.pair('option', atrs, HDML.text(label)));
      }
      R.push(HDML.close('select'));
      R.push(HDML.pair('button', {
        type: 'submit'
      }, HDML.text("submit")));
      R.push(HDML.close('form'));
      R.push(HDML.close('nav'));
      return R.join('\n');
    }

    _query_as_html(table, query, parameters) {
      var rows, table_cfg;
      table_cfg = this._get_table_cfg(table);
      rows = this.db(query, parameters);
      return tabulate({rows, ...table_cfg});
    }

    _table_as_html(table) {
      var query, rows, table_cfg;
      table_cfg = this._get_table_cfg(table);
      query = SQL`select * from ${this.db.sql.I(table)};`;
      rows = this.db(query);
      return tabulate({rows, ...table_cfg});
    }

    _get_table_cfg(table) {
      var ref;
      if (this.table_cfgs == null) {
        this._set_table_cfgs();
      }
      return (ref = this.table_cfgs[table]) != null ? ref : null;
    }

    _set_table_cfgs() {
      GUY.props.hide(this, 'table_cfgs', {});
      //.......................................................................................................
      this.table_cfgs['sqlite_schema'] = {
        fields: {
          name: {
            hide: false,
            inner_html: (d) => {
              var href, ref;
              href = this.router.url('relation', d.value);
              debug('^inner_html@234^', rpr(d.value), rpr(href));
              return HDML.pair('a', {href}, HDML.text((ref = d.value) != null ? ref : './.'));
            }
          },
          table_name: {
            hide: true
          },
          type: {
            hide: false
          },
          rootpage: {
            hide: true
          },
          sql: {
            title: "SQL",
            inner_html: (d) => {
              var ref;
              return HDML.pair('pre', HDML.text((ref = d.value) != null ? ref : './.'));
            }
          }
        }
      };
      //.......................................................................................................
      // @table_cfgs[ 'trends' ] =
      //   fields:
      //     #...................................................................................................
      //     dsk:
      //       hide: true
      //     #...................................................................................................
      //     sid_min:
      //       hide: true
      //     sid_max:
      //       title:  "SIDs"
      //       inner_html: ( d ) =>
      //         { sid_min
      //           sid_max } = d.row
      //         return sid_min if sid_min is sid_max
      //         return "#{sid_min}—#{sid_max}"
      //     #...................................................................................................
      //     ts:
      //       inner_html: ( d ) => @db.dt_format d.value, 'YYYY-MM-DD HH:mm UTC'
      //     #...................................................................................................
      //     raw_trend:
      //       title:  "Trend"
      //       outer_html:   ({ value: raw_trend }) =>
      //         return HDML.pair 'td.trend.sparkline', { 'data-trend': raw_trend, }
      //     #...................................................................................................
      //     details:
      //       inner_html:   ( d ) =>
      //         try row = JSON.parse d.value catch error
      //           return HDML.pair 'div.error', HDML.text error.message
      //         cfg =
      //           row:        row
      //           fields:
      //             title:
      //               title:      "Title"
      //               inner_html: ({ value: title, row, }) =>
      //                 return HDML.pair 'a', { href: row.title_url, }, HDML.text title
      //             title_url:
      //               hide: true
      //             article:
      //               title:      "Article"
      //               inner_html: ({ value: title, row, }) =>
      //                 return Symbol.for 'hide' unless title?
      //                 return Symbol.for 'hide' unless row.article_url?
      //                 return HDML.pair 'a', { href: row.article_url, }, HDML.text title
      //             article_url:
      //               hide: true
      //         return summarize cfg
      return null;
    }

  };

  // #---------------------------------------------------------------------------------------------------------
// _r_layout_demo: ( ctx ) =>
//   R                   = []
//   #.......................................................................................................
//   R.push HDML.open  'nav'
//   R.push HDML.open  'menu'
//   R.push HDML.pair  'li', HDML.pair 'a', { href: '#', }, HDML.text "one"
//   R.push HDML.pair  'li', HDML.pair 'a', { href: '#', }, HDML.text "two"
//   R.push HDML.pair  'li', HDML.pair 'a', { href: '#', }, HDML.text "three"
//   R.push HDML.close 'menu'
//   R.push HDML.close 'nav'
//   #.......................................................................................................
//   R.push HDML.pair  'header', HDML.text "header"
//   #.......................................................................................................
//   R.push HDML.open  'main'
//   R.push HDML.open  'article'
//   R.push HDML.text  "article"
//   R.push HDML.close 'article'
//   R.push HDML.close 'main'
//   #.......................................................................................................
//   R.push HDML.pair  'footer', HDML.text "footer"
//   #.......................................................................................................
//   ctx.response.type   = 'html'
//   ctx.body            =  R.join '\n'
//   return null

}).call(this);

//# sourceMappingURL=server.js.map