(function() {
  'use strict';
  var $, $async, $watch, CND, DATOM, DM, H, SPX, VNR, assign, badge, debug, declare, echo, first, freeze, fresh_datom, help, info, is_stamped, isa, jr, last, rpr, select, size_of, stamp, thaw, type_of, types, urge, validate, warn, whisper;

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

  DM = require('..');

  //...........................................................................................................
  SPX = require('./steampipes-extra');

  ({$, $watch, $async} = SPX.export());

  //...........................................................................................................
  DATOM = require('datom');

  ({VNR} = DATOM);

  ({freeze, thaw, fresh_datom, is_stamped, select, stamp} = DATOM.export());

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, declare, size_of, type_of} = types);

  //-----------------------------------------------------------------------------------------------------------
  this.$trim = function(S) {
    var ref;
    ref = 'ws1/trm';
    return $((d, send) => {
      var new_text;
      if (!select(d, '^line')) {
        return send(d);
      }
      if ((new_text = d.text.trimEnd()) !== d.text) {
        d = DATOM.set(d, {
          text: new_text,
          ref
        });
      }
      send(d);
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$group_blank_lines = function(S) {
    var $group, $unpack, pipeline;
    pipeline = [];
    //.........................................................................................................
    $group = () => {
      return SPX.$group_by(function(d) {
        if ((select(d, '^line')) && (d.text === '')) {
          return 'blank';
        }
        return 'other';
      });
    };
    //.........................................................................................................
    $unpack = () => {
      return $((group, send) => {
        var $vnr, buffer, d, i, j, len, len1, linecount, ref;
        buffer = group.value;
        //.......................................................................................................
        if (group.name === 'blank') {
          d = buffer[0];
          $vnr = VNR.deepen(d.$vnr);
          linecount = buffer.length;
          ref = 'ws1/gbl';
          send(H.fresh_datom('^blank', {$vnr, linecount, ref}));
          for (i = 0, len = buffer.length; i < len; i++) {
            d = buffer[i];
            send(stamp(d));
          }
        } else {
//.......................................................................................................
          for (j = 0, len1 = buffer.length; j < len1; j++) {
            d = buffer[j];
            send(d);
          }
        }
        return null;
      });
    };
    //.........................................................................................................
    pipeline.push($group());
    pipeline.push($unpack());
    return SPX.pull(...pipeline);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$ensure_blanks_at_ends = function(S) {
    /* Make sure to include blanks as first and last lines in document or fragment. */
    // first = Symbol 'first'
    // last  = Symbol 'last'
    H.register_key(S, '^blank', {
      is_block: false
    });
    //.........................................................................................................
    // return H.resume_from_db_after S, { realm: 'html', }, SPX.$mark_position $ ( pd, send ) =>
    // return H.leapfrog_stamped SPX.mark_position $ ( pd, send ) =>
    return SPX.mark_position($((pd, send) => {
      var $vnr, d, is_first, is_last, ref;
      ({is_first, is_last, d} = pd);
      if (is_stamped(d)) {
        //.......................................................................................................
        return send(d);
      }
      //.......................................................................................................
      /* Make sure the first thing in document or fragment is a blank: */
      if (is_first && (!select(d, '^blank'))) {
        // debug '^ensure_blanks_at_ends@334^', ( stamp d )
        send(stamp(d));
        ref = 'ws1/ebae1';
        $vnr = VNR.deepen(d.$vnr);
        // debug '^ensure_blanks_at_ends@445^', d
        // debug '^ensure_blanks_at_ends@445^', { $vnr, VNR_receded: ( VNR.recede $vnr ) }
        send(H.fresh_datom('^blank', {
          $vnr: VNR.recede($vnr),
          linecount: 0,
          ref
        }));
        debug('^ebae1@9833-1^', d);
        debug('^ebae1@9833-2^', DATOM.set(d, {
          $vnr,
          $fresh: true,
          ref
        }));
        send(DATOM.set(d, {
          $vnr,
          $fresh: true,
          ref
        }));
        /* If the sole line in document or fragment is not a blank line, make sure it is followed by a
             blank; we do this here and not in the next clause, below, to avoid sending a duplicate of the
             the text line: */
        if (is_last) {
          send(H.fresh_datom('^blank', {
            $vnr: VNR.advance($vnr),
            linecount: 0,
            ref
          }));
        }
      //.......................................................................................................
      /* Make sure the last thing in document or fragment is a blank: */
      } else if (is_last && (!select(d, '^blank'))) {
        send(stamp(d));
        ref = 'ws1/ebae2';
        $vnr = VNR.deepen(d.$vnr);
        send(H.fresh_datom('^blank', {
          $vnr: VNR.advance($vnr),
          linecount: 0,
          ref
        }));
        send(DATOM.set(d, {
          $vnr,
          $fresh: true,
          ref
        }));
      } else {
        send(d);
      }
      return null;
    }));
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$trim(S));
    pipeline.push(this.$group_blank_lines(S));
    pipeline.push(this.$ensure_blanks_at_ends(S));
    return SPX.pull(...pipeline);
  };

}).call(this);

//# sourceMappingURL=010-1-whitespace.js.map