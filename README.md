
# DataMill

A DB-backed text document processor built on
[`pipedreams`](https://github.com/loveencounterflow/pipedreams),
[`icql`](https://github.com/loveencounterflow/icql) and
[`mkts-mirage`](https://github.com/loveencounterflow/mkts-mirage).

While many simple applications can do without any SLPs (and could consider to use the more bare-bones
PipeStreams library instead), more advanced applications, in particular DB backed multi-pass streams (what
I call 'data mills'), cannot do without them.

* A text document is mirrored into the database; each line with number `lnr` of source text becomes one
  record in a DB table with the vectorial number `[ lnr ]` (that's an array with a single element).

* Upon processing, lines are read from the DB consecutively; they enter the stream as datoms with a `~vnr =
  [ lnr ]`; none of `~dirty`, `~fresh`, `~stamped` are set.

* Each line gets parsed by any number of stream transforms. Some transforms will output target
  representations, others may output another immediate representation that may or may not get re-processed
  within the same pass further down the line.

* As each line of text (top-level record from the DB) gets turned into smaller chunks, it is marked as
  'processed' by setting its `~stamped` property to `true`, and, consequently, also its `~dirty` flag,
  thereby indicating a DB update is in order for the corresponding record.

* As transforms handle parts of the source text they may produce any number of new—'fresh'—datoms, and those
  datoms that originate not from the DB but from within the stream will be flagged `d[ '~fresh' ] = true`.
  Furthermore, the first datom `d1` that is derived from a record bearing a vectorial line number of, say,
  `d[ '~vlnr' ] = [ 42 ]`, will be indexed as `d1[ '~vlnr' ] = [ 42, 1 ]`, the subsequent one will be `[ 42,
  2 ]` and so on.


