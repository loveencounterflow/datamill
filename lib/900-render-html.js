(function() {
  'use strict';
  var $, $async, $watch, CND, DATOM, DM, FS, H, MIRAGE, PATH, SPX, VNR, assign, badge, cast, cwd_abspath, cwd_relpath, debug, echo, first, first_of, freeze, help, here_abspath, info, is_stamped, isa, jr, last, last_of, new_datom, project_abspath, rpr, select, size_of, stamp, thaw, type_of, urge, validate, warn, whisper, xr;

  //###########################################################################################################
  CND = require('cnd');

  rpr = CND.rpr;

  badge = 'DATAMILL/MAIN';

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  info = CND.get_logger('info', badge);

  urge = CND.get_logger('urge', badge);

  help = CND.get_logger('help', badge);

  whisper = CND.get_logger('whisper', badge);

  echo = CND.echo.bind(CND);

  ({jr, assign} = CND);

  //...........................................................................................................
  first = Symbol('first');

  last = Symbol('last');

  MIRAGE = require('mkts-mirage');

  FS = require('fs');

  PATH = require('path');

  //...........................................................................................................
  SPX = require('./steampipes-extra');

  ({$, $watch, $async} = SPX.export());

  //...........................................................................................................
  DATOM = require('datom');

  ({VNR} = DATOM);

  ({freeze, thaw, new_datom, is_stamped, select, stamp} = DATOM.export());

  //...........................................................................................................
  this.types = require('./types');

  ({isa, validate, cast, first_of, last_of, size_of, type_of} = this.types);

  //...........................................................................................................
  H = require('./helpers');

  ({cwd_abspath, cwd_relpath, here_abspath, project_abspath} = H);

  //...........................................................................................................
  DM = require('..');

  ({xr} = require('./xr'));

  // #-----------------------------------------------------------------------------------------------------------
  // @$decorations = ( S ) -> $ { first, last, }, ( d, send ) =>
  //   if d is first
  //     send H.fresh_datom '^html', { text: '<html><body>', ref: 'rdh/deco-1', $vnr: [ -Infinity, ], }
  //   if d is last
  //     send H.fresh_datom '^html', { text: '</body></html>', ref: 'rdh/deco-2', $vnr: [ Infinity, ], }
  //   else
  //     send d
  //   return null

  //-----------------------------------------------------------------------------------------------------------
  this.$headings = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(H.leapfrog_stamped(SPX.lookaround($((d3, send) => {
      var $vnr, d, nxt, prv, tagname, text;
      [prv, d, nxt] = d3;
      if (!((select(prv, '<h')) && (select(d, '^mktscript')) && (select(nxt, '>h')))) {
        return;
      }
      $vnr = VNR.deepen(d.$vnr);
      tagname = `h${prv.level}`;
      text = `<${tagname}>${d.text}</${tagname}>`;
      send(H.fresh_datom('^html', {
        text,
        ref: 'rdh/h',
        $vnr
      }));
      send(stamp(prv));
      send(stamp(d));
      return send(stamp(nxt));
    }))));
    //.........................................................................................................
    /* Make sure ordering is preserved for downstream transforms: */
    pipeline.push(H.$resume_from_db(S, {
      realm: 'html'
    }));
    return SPX.pull(...pipeline);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$blockquotes = function(S) {
    return $((d, send) => {
      var $vnr, text;
      if (select(d, '<blockquote')) {
        $vnr = VNR.deepen(d.$vnr);
        text = "<blockquote>";
        send(H.fresh_datom('^html', {
          text,
          ref: 'rdh/blqt1',
          $vnr
        }));
        send(stamp(d));
      } else if (select(d, '>blockquote')) {
        $vnr = VNR.deepen(d.$vnr);
        text = "</blockquote>";
        send(H.fresh_datom('^html', {
          text,
          ref: 'rdh/blqt2',
          $vnr
        }));
        send(stamp(d));
      } else {
        send(d);
      }
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$codeblocks = function(S) {
    return H.leapfrog_stamped(SPX.lookaround($((d3, send) => {
      var $vnr, d, nxt, prv, text;
      [prv, d, nxt] = d3;
      if (!select(d, '^literal')) {
        return send(d);
      }
      if (select(prv, '<codeblock')) {
        $vnr = VNR.deepen(prv.$vnr);
        text = "<pre><code>";
        send(H.fresh_datom('^html', {
          text,
          ref: 'rdh/cdb1',
          $vnr
        }));
        send(stamp(prv));
      }
      if (select(nxt, '>codeblock')) {
        $vnr = VNR.deepen(nxt.$vnr);
        text = "</code></pre>";
        send(H.fresh_datom('^html', {
          text,
          ref: 'rdh/cdb2',
          $vnr
        }));
        send(stamp(nxt));
      }
      $vnr = VNR.deepen(d.$vnr);
      send(H.fresh_datom('^html', {
        text: d.text,
        ref: 'rdh/cdb3',
        $vnr
      }));
      return send(stamp(d));
    })));
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$blocks_with_mktscript = function(S) {
    var is_block, key_registry, pipeline;
    key_registry = H.get_key_registry(S);
    is_block = function(d) {
      var ref;
      return (ref = key_registry[d.key]) != null ? ref.is_block : void 0;
    };
    pipeline = [];
    pipeline.push(H.leapfrog_stamped(SPX.lookaround($((d3, send) => {
      /* TAINT use proper HTML generation */
      var $vnr, d, nxt, prv, tagname, text;
      [prv, d, nxt] = d3;
      if (!select(d, '^mktscript')) {
        return send(d);
      }
      text = d.text;
      /* TAINT use proper API to detect open, close */
      if ((is_block(prv)) && (prv.key.startsWith('<'))) {
        tagname = prv.key.slice(1);
        text = `<${tagname}>${text}`;
        send(stamp(prv));
      }
      /* TAINT use proper API to detect open, close */
      if ((is_block(nxt)) && (nxt.key.startsWith('>'))) {
        // debug 'µ10981-1', xr prv
        // debug 'µ10981-2', xr d
        // debug 'µ10981-3', xr nxt
        tagname = nxt.key.slice(1);
        text = `${text}</${tagname}>`;
        send(stamp(nxt));
      }
      $vnr = VNR.deepen(d.$vnr);
      send(H.fresh_datom('^html', {
        text,
        ref: 'rdh/bwm',
        $vnr
      }));
      send(stamp(d));
      return null;
    }))));
    //.........................................................................................................
    /* Make sure ordering is preserved for downstream transforms: */
    pipeline.push(H.$resume_from_db(S, {
      realm: 'html'
    }));
    return SPX.pull(...pipeline);
  };

  // #-----------------------------------------------------------------------------------------------------------
  // @$other_blocks = ( S ) ->
  //   key_registry    = H.get_key_registry S
  //   is_block        = ( d ) -> key_registry[ d.key ]?.is_block
  //   return H.resume_from_db S, { realm: 'html', }, $ ( d, send ) =>
  //     return send d unless ( select d, '<>' ) and ( is_block d )
  //     debug 'µ29882', '$other_blocks', jr d
  //     tagname = d.key[ 1 .. ]
  //     ### TAINT use proper HTML generation ###
  //     if select d, '<' then text = "<#{tagname}>"
  //     else                  text = "</#{tagname}>"
  //     $vnr = VNR.deepen d.$vnr
  //     send H.fresh_datom '^html', { text: text, ref: 'rdh/ob', $vnr, }
  //     send stamp d
  //     return null

  //-----------------------------------------------------------------------------------------------------------
  // @$blank = ( S ) -> $ ( d, send ) =>
  this.$blank = function(S) {
    return H.resume_from_db_after(S, {
      realm: 'html'
    }, $((d, send) => {
      var $vnr, linecount, ref, text;
      if (!select(d, '^blank')) {
        return send(d);
      }
      $vnr = VNR.deepen(d.$vnr);
      send(stamp(d));
      if ((linecount = ((ref = d.linecount) != null ? ref : 0) - 1) > -1) {
        text = '\n'.repeat(linecount);
        send(H.fresh_datom('^html', {
          text,
          ref: 'rdh/blnk',
          $vnr
        }));
      }
      return null;
    }));
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  /* TAINT refactor to PipeStreams */
  SPX.$send_as_first = function(x) {
    return $({first}, function(d, send) {
      return send(d === first ? x : d);
    });
  };

  SPX.$send_as_last = function(x) {
    return $({last}, function(d, send) {
      return send(d === last ? x : d);
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this._get_preamble = function() {
    var path;
    path = PATH.join(__dirname, '../public/preamble.html');
    return FS.readFileSync(path, {
      encoding: 'utf-8'
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.retrieve_html = function(S) {
    return new Promise((resolve) => {
      /* TAINT code duplication */
      var collector, pipeline;
      collector = [];
      pipeline = [];
      pipeline.push(H.new_db_source(S, 'html'));
      pipeline.push(SPX.$filter(function(d) {
        return select(d, '^html');
      }));
      pipeline.push($(function(d, send) {
        return send(d.text);
      }));
      pipeline.push(SPX.$collect({collector}));
      pipeline.push(SPX.$send_as_first(this._get_preamble(S)));
      pipeline.push(SPX.$drain(function() {
        return resolve(collector.join('\n'));
      }));
      return SPX.pull(...pipeline);
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.write_to_file = (S) => {
    return new Promise((resolve) => {
      /* TAINT code duplication */
      var pipeline;
      pipeline = [];
      pipeline.push(H.new_db_source(S, 'html'));
      pipeline.push(SPX.$filter(function(d) {
        return select(d, '^html');
      }));
      pipeline.push($(function(d, send) {
        return send(d.text + '\n');
      }));
      pipeline.push(SPX.$send_as_first(this._get_preamble(S)));
      pipeline.push(SPX.$tee(SPX.write_to_file('/tmp/datamill.html')));
      pipeline.push(SPX.$drain(function() {
        return resolve();
      }));
      return SPX.$tee(SPX.pull(...pipeline));
    });
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.settings = {
    from_realm: 'html',
    to_realm: 'html'
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    H.register_key(S, '^html', {
      is_block: false
    });
    H.register_realm(S, this.settings.to_realm);
    H.copy_realm(S, 'input', 'html');
    pipeline = [];
    pipeline.push(this.$headings(S));
    pipeline.push(this.$blockquotes(S));
    pipeline.push(this.$codeblocks(S));
    pipeline.push(this.$blocks_with_mktscript(S));
    pipeline.push(this.$blank(S));
    pipeline.push(H.$set_realm_where_missing(S, this.settings.to_realm));
    // pipeline.push @$write_to_file             S
    return SPX.pull(...pipeline);
  };

}).call(this);

//# sourceMappingURL=900-render-html.js.map