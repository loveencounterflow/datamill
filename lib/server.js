(function() {
  'use strict';
  var CKD, Datamill_server, Datamill_server_base, FS, GUY, HDML, HTTP, Koa, NODEXH, PATH, Router, SQL, Socket_server, XE, alert, debug, echo, file_server, get_base_types, get_server_types, help, info, inspect, isa, log, mount, plain, praise, rpr, summarize, tabulate, type_of, types, urge, warn, whisper;

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

  NODEXH = require('../../nodexh');

  CKD = require('chokidar');

  ({XE} = require('./_xemitter'));

  //===========================================================================================================
  Datamill_server_base = class Datamill_server_base {
    constructor() {
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
      this._r_tables = this._r_tables.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._r_table = this._r_table.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._table_by_name = this._table_by_name.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._query_as_html = this._query_as_html.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._table_as_html = this._table_as_html.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._get_table_cfg = this._get_table_cfg.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._set_table_cfgs = this._set_table_cfgs.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._r_doc = this._r_doc.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._r_files = this._r_files.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this._r_file = this._r_file.bind(this);
    }

    //---------------------------------------------------------------------------------------------------------
    _watch_doc_files() {
      var cfg, watcher;
      cfg = {
        recursive: true,
        persistent: true,
        awaitWriteFinish: {
          stabilityThreshold: 100
        }
      };
      watcher = CKD.watch(this.doc.cfg.home, cfg);
      urge('^3534^', "watching @{doc.cfg.home}");
      watcher.on('add', (doc_file_abspath) => {
        return info('^3534^', GUY.trm.reverse('add', doc_file_abspath));
      });
      watcher.on('unlink', (doc_file_abspath) => {
        return warn('^3534^', GUY.trm.reverse('unlink', doc_file_abspath));
      });
      watcher.on('error', (error) => {
        return alter('^3534^', GUY.trm.reverse('error', error));
      });
      //.......................................................................................................
      watcher.on('change', async(doc_file_abspath) => {
        urge('^3534^', GUY.trm.reverse('change', doc_file_abspath));
        await XE.emit('^maybe-file-changed', {doc_file_abspath});
        return null;
      });
      //.......................................................................................................
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
      /* TAINT differentiate between documents and files */
      /* TAINT generate from DB or load from external file */
      var doc_url, files_url, table_url;
      table_url = this.router.url('table', 'sqlite_schema');
      doc_url = this.router.url('doc', 'f1');
      files_url = this.router.url('files');
      debug('^32234^', {table_url, doc_url, files_url});
      ctx.body = `<h1>Datamill</h1>
<ul>
  <li><a href=${doc_url}>Document</a></li>
  <li><a href=${files_url}>Files</a></li>
  <li><a href=${table_url}>Relations (Tables &amp; Views)</a></li>
  </ul>`;
      // help "^datamill/server@7^", ctx.router.url 'home', { query: { foo: 'bar', }, }
      return null;
    }

    _r_tables(ctx) {
      return this._table_by_name(ctx, 'sqlite_schema');
    }

    _r_table(ctx) {
      var ref, table_name;
      table_name = (ref = ctx.params.rel) != null ? ref : 'sqlite_schema';
      if (table_name === '') {
        table_name = 'sqlite_schema';
      }
      return this._table_by_name(ctx, table_name);
      return null;
    }

    _table_by_name(ctx, table_name) {
      var R, error, rows, table_cfg;
      R = [];
      R.push(HDML.pair('h1', HDML.text(`Table ${table_name}`)));
      try {
        //.......................................................................................................
        /* TAINT use proper interpolation or API */
        rows = this.doc.db.all_rows(SQL`select * from ${table_name} order by 1;`);
      } catch (error1) {
        error = error1;
        ctx.response.status = 500;
        ctx.response.type = 'text/plain';
        ctx.body = error.message;
        return null;
      }
      //.......................................................................................................
      if ((table_cfg = this._get_table_cfg(table_name)) == null) {
        // ctx.response.status = 404
        // ctx.response.type   = 'text/plain'
        // ctx.body            = "no such table: #{table_name}"
        // return null
        table_cfg = null;
      }
      //.......................................................................................................
      R = R.concat(tabulate({rows, ...table_cfg}));
      ctx.response.type = 'html';
      ctx.body = R.join('\n');
      return null;
    }

    _query_as_html(table, query, parameters) {
      var rows, table_cfg;
      table_cfg = this._get_table_cfg(table);
      rows = this.doc.db(query, parameters);
      return tabulate({rows, ...table_cfg});
    }

    _table_as_html(table) {
      var query, rows, table_cfg;
      table_cfg = this._get_table_cfg(table);
      query = SQL`select * from ${this.doc.db.sql.I(table)};`;
      rows = this.doc.db(query);
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
              href = this.router.url('table', d.value);
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
      return null;
    }

    _r_doc(ctx) {
      var lines;
      /* TAINT use streaming */
      /* TAINT use API */
      /* TAINT allow other values for `doc_file_id` */
      /* TAINT respect custom table prefix */
      ctx.response.type = 'html';
      lines = this.doc.db.all_first_values(SQL`select
    doc_line_txt
  from doc_lines
  where doc_file_id = 'f1'
  order by doc_line_nr;`);
      ctx.body = lines.join('\n');
      return null;
    }

    _r_files(ctx) {
      var R, file, href, ref;
      /* TAINT use layout */
      /* TAINT use API */
      /* TAINT respect custom table prefix */
      ctx.response.type = 'html';
      R = [];
      R.push(HDML.pair('h1', HDML.text("Datamill")));
      R.push(HDML.pair('h2', HDML.text("Files")));
      R.push(HDML.open('ul'));
      ref = this.doc.db(SQL`select * from doc_files order by 1, 2;`);
      for (file of ref) {
        href = this.router.url('file', file.doc_file_id);
        R.push(HDML.pair('li', HDML.pair('a', {href}, HDML.text(file.doc_file_path))));
      }
      R.push(HDML.close('ul'));
      ctx.body = R.join('\n');
      return null;
    }

    _r_file(ctx) {
      var doc_file_id, lines;
      /* TAINT use streaming */
      /* TAINT use layout */
      /* TAINT use API */
      /* TAINT respect custom table prefix */
      ctx.response.type = 'text/plain';
      doc_file_id = ctx.params.dfid;
      lines = this.doc.db.all_first_values(SQL`select
    doc_line_txt
  from doc_lines
  where doc_file_id = $doc_file_id
  order by doc_line_nr;`, {doc_file_id});
      debug('^3284723894^', {
        params: ctx.params,
        doc_file_id,
        lines
      });
      ctx.body = lines.join('\n');
      return null;
    }

    //=========================================================================================================
    // ERROR HANDLING
    //---------------------------------------------------------------------------------------------------------
    $error_handler() {
      return async(error, ctx) => {
        var message, prefix, ref, url;
        if ((url = ctx != null ? ctx.request.url : void 0) != null) {
          prefix = `When trying to retrieve ${rpr(url)}, an `;
        } else {
          prefix = "An ";
        }
        message = prefix + `error with message ${rpr((ref = error.message) != null ? ref : "UNKNOWN")} was encountered`;
        warn('^3298572^', error);
        warn(GUY.trm.reverse('^3298572^', message));
        debug('^323423^', (await NODEXH._exit_handler(error)));
        return null;
      };
    }

  };

  //===========================================================================================================
  Datamill_server = class Datamill_server extends Datamill_server_base {
    //=========================================================================================================
    // CONSTRUCTION
    //---------------------------------------------------------------------------------------------------------
    constructor(cfg) {
      super();
      GUY.props.hide(this, 'types', get_server_types());
      this.cfg = this.types.create.datamill_server_cfg(cfg);
      GUY.props.hide(this, 'doc', this.cfg.doc);
      delete this.cfg.doc;
      this._add_layout();
      // debug '^3325936^', @cfg
      this.cfg = Object.freeze(this.cfg);
      //.......................................................................................................
      GUY.props.hide(this, 'app', new Koa());
      GUY.props.hide(this, 'router', new Router());
      //.......................................................................................................
      this._watch_doc_files();
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

    //=========================================================================================================
    // RUN SERVER
    //---------------------------------------------------------------------------------------------------------
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

    //---------------------------------------------------------------------------------------------------------
    _create_app() {
      /*
      `_r_*`: managed by router
      `_s_*`: managed by server
      */
      this.app.use(this._s_log);
      this.app.use(this._s_layout);
      //.......................................................................................................
      this.router.get('home', '/', this._r_home);
      this.router.get('tables', '/tables', this._r_tables);
      this.router.get('table', '/table/:rel', this._r_table);
      this.router.get('files', '/files', this._r_files);
      this.router.get('file', '/file/:dfid', this._r_file);
      /* TAINT differentiate between 'documents' and 'files' */
      // @router.get   'docs',           '/docs',          @_r_docs
      this.router.get('doc', '/doc/:dfid', this._r_doc);
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
      //.......................................................................................................
      this.app.on('error', this.$error_handler());
      return null;
    }

  };

  //###########################################################################################################
  module.exports = {Datamill_server_base, Datamill_server};

}).call(this);

//# sourceMappingURL=server.js.map