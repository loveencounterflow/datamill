(function() {
  'use strict';
  var $, $async, $watch, CND, DATOM, H, SPX, VNR, alert, assign, badge, debug, declare, echo, first, freeze, help, info, is_stamped, isa, jr, last, last_of, new_datom, rpr, select, size_of, stamp, thaw, type_of, types, urge, validate, warn, whisper, xr;

  //###########################################################################################################
  H = require('./helpers');

  CND = require('cnd');

  rpr = CND.rpr;

  badge = H.badge_from_filename(__filename);

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  alert = CND.get_logger('alert', badge);

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

  ({freeze, thaw, new_datom, is_stamped, select, stamp} = DATOM.export());

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, declare, size_of, last_of, type_of} = types);

  //...........................................................................................................
  ({xr} = require('./xr'));

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  /* TAINT consider to move this to steampipes */
  this.$validate_symmetric_keys = function(settings) {
    var stack, vnr;
    stack = [];
    vnr = null;
    return SPX.mark_position($((pd, send) => {
      /* TAINT make configurable whether to throw or warn */
      var $key, d, entry, i, is_first, is_last, is_vnr, len, message, name, ref, sigil, was_vnr;
      ({is_first, is_last, d} = pd);
      //.......................................................................................................
      if (is_last) {
        if (!isa.empty(stack)) {
          is_vnr = jr(vnr);
          ref = d.ref != null ? `ref: ${d.ref}` : "(no ref)";
          message = ['µ44333'];
          message = [`at document end (VNR ${is_vnr}, ${ref}), encountered dangling open tag(s):`];
          for (i = 0, len = stack.length; i < len; i++) {
            entry = stack[i];
            was_vnr = jr(entry.$vnr);
            message.push(`\`>${entry.name}\` (VNR ${was_vnr})`);
          }
          message = message.join(' ');
          send(SPX.new_datom('~error', {
            message,
            $: d
          }));
        }
        return null;
      }
      //.......................................................................................................
      vnr = d.$vnr;
      is_vnr = jr(vnr);
      $key = d.$key;
      sigil = $key[0];
      name = $key.slice(1);
      ref = d.ref != null ? `ref: ${d.ref}` : "(no ref)";
      //.......................................................................................................
      switch (sigil) {
        case '<':
          stack.push({
            name,
            $vnr: d.$vnr
          });
          break;
        case '>':
          if (isa.empty(stack)) {
            message = `µ44332 extraneous closing $key \`>${name}\` found at (VNR ${is_vnr}, ${ref}), stack empty`;
            send(SPX.new_datom('~error', {
              message,
              $: d
            }));
          }
          entry = last_of(stack);
          if (entry.name !== name) {
            was_vnr = jr(entry.$vnr);
            message = `µ44332 expected \`>${entry.name}\` (VNR ${was_vnr}), found \`${$key}\` (VNR ${is_vnr}, ${ref})`;
            send(SPX.new_datom('~error', {
              message,
              $: d
            }));
          }
          stack.pop();
          break;
        default:
          send(d);
      }
      return null;
    }));
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$complain_on_error = function() {
    var count;
    count = 0;
    return $({last}, (d, send) => {
      if (d === last) {
        if (count > 0) {
          alert(`µ77874 found ${count} faults`);
        }
        return null;
      }
      if (!select(d, '~error')) {
        return send(d);
      }
      send(SPX.set(d.$, {
        error: d.message
      }));
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$exit_on_error = function() {
    var messages;
    messages = [];
    return $({last}, (d, send) => {
      var message;
      if (d === last) {
        if (messages.length > 0) {
          message = messages.join('\n\n');
          throw new Error(`µ77874 found ${messages.length} faults: \n\n${message}`);
        }
      }
      if (!select(d, '~error')) {
        return send(d);
      }
      messages.push(d.message);
      return null;
    });
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$validate_symmetric_keys(S));
    pipeline.push(this.$complain_on_error(S));
    // pipeline.push @$exit_on_error             S
    return SPX.pull(...pipeline);
  };

}).call(this);

//# sourceMappingURL=xxx-validation.js.map