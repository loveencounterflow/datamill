(function() {
  'use strict';
  var $, $async, $watch, CND, DATOM, H, SPX, VNR, assign, badge, debug, declare, echo, first, freeze, help, info, is_stamped, isa, jr, last, last_of, rpr, select, size_of, stamp, thaw, type_of, types, urge, validate, warn, whisper;

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
  first = Symbol('first');

  last = Symbol('last');

  //...........................................................................................................
  SPX = require('./steampipes-extra');

  ({$, $watch, $async} = SPX.export());

  //...........................................................................................................
  DATOM = require('datom');

  ({VNR} = DATOM);

  ({freeze, thaw, is_stamped, select, stamp} = DATOM.export());

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, declare, size_of, last_of, type_of} = types);

  //...........................................................................................................

  //-----------------------------------------------------------------------------------------------------------
  this.$paragraphs = function(S) {
    var key_registry, prv_was_blank, skip, stack, within_p;
    H.register_key(S, '<p', {
      is_block: true
    });
    H.register_key(S, '>p', {
      is_block: true
    });
    within_p = false;
    prv_was_blank = false;
    key_registry = H.get_key_registry(S);
    stack = [];
    //.........................................................................................................
    skip = function() {
      var entry;
      if (stack.length === 0) {
        return false;
      }
      entry = last_of(stack);
      return entry.is_block && !entry.has_paragraphs;
    };
    //.........................................................................................................
    return $((d, send) => {
      var $vnr, dest, entry, ref;
      if ((entry = key_registry[d.$key]) == null) {
        warn('^$paragraphs@4452^', key_registry);
        throw new Error(`^$paragraphs@4452^ unregistered key ${rpr(d.$key)} from ${rpr(d)}`);
      }
      if (entry.is_block) {
        if (d.$key.startsWith('<')) {
          stack.push(entry);
        } else {
          stack.pop();
        }
        return send(d);
      }
      if (skip()) {
        return send(d);
      }
      //.......................................................................................................
      if (select(d, '^blank')) {
        if (within_p) {
          send(stamp(d));
          ref = 'pco/p1';
          dest = d.dest;
          $vnr = VNR.deepen(d.$vnr, 0);
          send(DATOM.set(d, {
            $vnr,
            dest,
            ref,
            $fresh: true
          }));
          send(H.fresh_datom('>p', {
            $vnr: VNR.recede($vnr),
            dest,
            ref
          }));
          within_p = false;
        } else {
          send(d);
        }
        prv_was_blank = true;
      //.......................................................................................................
      } else if (select(d, '^line')) {
        if (prv_was_blank) {
          ref = 'pco/p2';
          dest = d.dest;
          $vnr = VNR.deepen(d.$vnr, 0);
          send(H.fresh_datom('<p', {
            $vnr: VNR.recede($vnr),
            dest,
            ref
          }));
          send(DATOM.set(d, {$vnr, ref}));
          within_p = true;
          send(stamp(d));
        } else {
          send(d);
        }
        prv_was_blank = false;
      } else {
        //.......................................................................................................
        send(d);
      }
      //.......................................................................................................
      return null;
    });
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$paragraphs(S));
    // pipeline.push SPX.$show { title: __filename, }
    return SPX.pull(...pipeline);
  };

}).call(this);

//# sourceMappingURL=030-paragraphs.js.map