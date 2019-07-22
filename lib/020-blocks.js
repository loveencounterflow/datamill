(function() {
  'use strict';
  var $, $async, $watch, CND, DM, H, PD, VNR, assign, badge, debug, declare, echo, first, help, info, isa, jr, last, rpr, select, size_of, stamp, type_of, types, urge, validate, warn, whisper, xr;

  //###########################################################################################################
  H = require('./helpers');

  CND = require('cnd');

  rpr = CND.rpr;

  badge = H.badge_from_filename(__filename);

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  info = CND.get_logger('info', badge);

  urge = CND.get_logger('urge', badge);

  help = CND.get_logger('help', badge);

  whisper = CND.get_logger('whisper', badge);

  echo = CND.echo.bind(CND);

  ({jr, assign} = CND);

  //...........................................................................................................
  require('./exception-handler');

  first = Symbol('first');

  last = Symbol('last');

  VNR = require('./vnr');

  //...........................................................................................................
  PD = require('pipedreams');

  ({$, $watch, $async, select, stamp} = PD);

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, declare, size_of, type_of} = types);

  //...........................................................................................................
  DM = require('..');

  ({xr} = require('./xr'));

  //-----------------------------------------------------------------------------------------------------------
  this.$codeblocks = function(S) {
    /* Recognize codeblocks as regions delimited by triple backticks. Possible extensions include
    markup for source code category and double service as pre-formatted blocks. */
    var pattern, within_codeblock;
    pattern = /^(?<backticks>```)$/;
    within_codeblock = false;
    H.register_key(S, '<codeblock', {
      is_block: true
    });
    H.register_key(S, '>codeblock', {
      is_block: true
    });
    H.register_key(S, '^literal', {
      is_block: false
    });
    H.register_key(S, '^literal-blank', {
      is_block: false
    });
    //.........................................................................................................
    return $((d, send) => {
      var dest, match;
      if (within_codeblock && select(d, '^blank')) {
        return send(PD.set(d, {
          key: '^literal-blank',
          ref: 'blk/cdb1'
        }));
      }
      if (!select(d, '^line')) {
        //.......................................................................................................
        return send(d);
      }
      //.......................................................................................................
      /* line starts or stops codeblock */
      if ((match = d.text.match(pattern)) != null) {
        within_codeblock = !within_codeblock;
        dest = d.dest;
        //.....................................................................................................
        if (within_codeblock) {
          send(stamp(d));
          send(PD.set(VNR.deepen(d), {
            key: '<codeblock',
            ref: 'blk/cdb2'
          }));
        } else {
          //.....................................................................................................
          send(stamp(d));
          send(PD.set(VNR.deepen(d), {
            key: '>codeblock',
            ref: 'blk/cdb3'
          }));
        }
      } else {
        //.......................................................................................................
        /* line is literal within, unchanged outside of codeblock */
        if (within_codeblock) {
          d = PD.set(d, {
            key: '^literal',
            ref: 'blk/cdb4'
          });
          send(d);
        } else {
          send(d);
        }
      }
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$headings = function(S) {
    /* Recognize heading as any line that starts with a `#` (hash). Current behavior is to
    check whether both prv and nxt lines are blank and if not so issue a warning; this detail may change
    in the future. */
    var pattern;
    pattern = /^(?<hashes>\#+)(?<text>.*)$/;
    //.........................................................................................................
    H.register_key(S, '<h', {
      is_block: true
    });
    H.register_key(S, '>h', {
      is_block: true
    });
    //.........................................................................................................
    return $((d, send) => {
      var $vnr, dest/* TAINT use trim method */, level, match, text;
      if (!select(d, '^line')) {
        return send(d);
      }
      if ((match = d.text.match(pattern)) == null) {
        return send(d);
      }
      send(stamp(d));
      level = match.groups.hashes.length;
      text = match.groups.text.replace(/^\s*(.*?)\s*$/g, '$1');
      dest = d.dest;
      $vnr = VNR.deepen(d.$vnr, 0);
      send(H.fresh_datom('<h', {
        level,
        $vnr: VNR.recede($vnr),
        dest,
        ref: 'blk/hd1'
      }));
      send(H.fresh_datom('^line', {
        text,
        $vnr,
        dest,
        ref: 'blk/hd2'
      }));
      send(H.fresh_datom('>h', {
        level,
        $vnr: VNR.advance($vnr),
        dest,
        ref: 'blk/hd3'
      }));
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$blockquotes = function(S) {
    /* TAINT ATM also captures closing pointy bracket of multiline tag literals */
    var $vnr, dest, first_vnr, pattern, within_quote;
    pattern = /^(?:(?<mu_1>>+)|(?<mu_2>>+)\s+(?<text>.*))$/;
    within_quote = false;
    first_vnr = null;
    $vnr = null;
    dest = null;
    /* TAINT only register once per pair */
    H.register_key(S, '<blockquote', {
      is_block: true,
      has_paragraphs: true
    });
    H.register_key(S, '>blockquote', {
      is_block: true,
      has_paragraphs: true
    });
    //.........................................................................................................
    return $({last}, (d, send) => {
      var markup, match, ref, ref1, text;
      if (d === last) {
        /* If the previous datom was the last in the document and we're within a blockwuote, close it: */
        /* TAINT code duplication */
        if (within_quote) {
          send(H.fresh_datom('>blockquote', {
            dest,
            $vnr: VNR.advance($vnr),
            ref: 'blk/bq1'
          }));
          /* TAINT is a single `deepen()` enough to capture proper boundaries? */
          DM.reprise(S, {
            first_vnr,
            last_vnr: VNR.deepen($vnr),
            ref: 'blk/bq2'
          });
          $vnr = null;
          first_vnr = null;
        }
        return null;
      }
      if (!select(d, '^line')) {
        //.......................................................................................................
        return send(d);
      }
      //.......................................................................................................
      if ((match = d.text.match(pattern)) == null) {
        //.....................................................................................................
        /* TAINT code duplication */
        /* If we've found a text that has no blockquote markup, the quote has ended: */
        if (within_quote) {
          send(H.fresh_datom('>blockquote', {
            dest,
            $vnr: VNR.advance($vnr),
            ref: 'blk/bq3'
          }));
          DM.reprise(S, {
            first_vnr,
            last_vnr: $vnr,
            ref: 'blk/bq4'
          });
          $vnr = null;
          first_vnr = null;
        }
        //.....................................................................................................
        within_quote = false;
        return send(d);
      }
      //.......................................................................................................
      markup = (ref = match.groups.mu_1) != null ? ref : match.groups.mu_2;
      text = (ref1 = match.groups.text) != null ? ref1 : '';
      $vnr = VNR.deepen(d.$vnr, 0);
      //.......................................................................................................
      if (!within_quote) {
        dest = d.dest;
        first_vnr = $vnr;
        send(H.fresh_datom('<blockquote', {
          dest,
          $vnr: VNR.recede($vnr),
          ref: 'blk/bq5'
        }));
        send(H.fresh_datom('^line', {
          text,
          dest,
          $vnr,
          ref: 'blk/bq6'
        }));
      } else {
        //.......................................................................................................
        dest = d.dest;
        send(H.fresh_datom('^line', {
          text,
          dest,
          $vnr,
          ref: 'blk/bq7'
        }));
      }
      //.......................................................................................................
      send(stamp(d));
      within_quote = true;
      return null;
    });
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$codeblocks(S));
    pipeline.push(this.$headings(S));
    pipeline.push(this.$blockquotes(S));
    return PD.pull(...pipeline);
  };

}).call(this);
