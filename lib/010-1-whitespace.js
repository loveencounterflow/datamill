(function() {
  'use strict';
  var $, $watch, CND, DM, H, PD, SP, VNR, assign, badge, debug, declare, echo, first, help, info, isa, jr, last, rpr, select, size_of, stamp, type_of, types, urge, validate, warn, whisper;

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

  DM = require('..');

  //...........................................................................................................
  SP = require('steampipes');

  PD = require('pipedreams');

  ({$, $watch} = SP.export());

  ({select, stamp} = PD.export());

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
        d = PD.set(d, {
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
      return PD.$group_by(function(d) {
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
    return SP.pull(...pipeline);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$ensure_blanks_at_ends = function(S) {
    /* Make sure to include blanks as first and last lines in document or fragment. */
    H.register_key(S, '^blank', {
      is_block: false
    });
    //.........................................................................................................
    // return H.resume_from_db_after S, { realm: 'html', }, PD.mark_position $ ( pd, send ) =>
    return H.leapfrog_stamped(PD.mark_position($((pd, send) => {
      var $vnr, d, is_first, is_last, ref;
      ({is_first, is_last, d} = pd);
      //.......................................................................................................
      /* Make sure the first thing in document or fragment is a blank: */
      if (is_first && !select(d, '^blank')) {
        send(stamp(d));
        ref = 'ws1/ebae1';
        $vnr = VNR.deepen(d.$vnr);
        send(H.fresh_datom('^blank', {
          $vnr: VNR.recede($vnr),
          linecount: 0,
          ref
        }));
        send(PD.set(d, {
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
      } else if (is_last && !select(d, '^blank')) {
        send(stamp(d));
        ref = 'ws1/ebae2';
        $vnr = VNR.deepen(d.$vnr);
        send(H.fresh_datom('^blank', {
          $vnr: VNR.advance($vnr),
          linecount: 0,
          ref
        }));
        send(PD.set(d, {
          $vnr,
          $fresh: true,
          ref
        }));
      } else {
        send(d);
      }
      return null;
    })));
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$trim(S));
    pipeline.push(this.$group_blank_lines(S));
    pipeline.push(this.$ensure_blanks_at_ends(S));
    return SP.pull(...pipeline);
  };

}).call(this);
