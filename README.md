
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


<!--

* recognize paragraphs; must recognize block-level tags to do so

* timetunnel
  * MKTScript / HTML tags
  * backslash-escaped literals

* parse special forms with markdown-it
  * consider to use a fork of https://github.com/markdown-it/markdown-it/blob/master/lib/rules_inline/emphasis.js
    so we don't parse underscores as emphasis, or cloak all underscores

 -->

## Phases

A phase should contain either regular stream transforms or else pseudo-transforms. Regular transforms work
on the datoms as they come down the pipeline and effects updates and insertions by `send`ing altered and
newly formed datoms into the stream; pseudo-transforms, by contrast, are called once per entire stream and
work directly with the rows in the database, doing its CRUD stuff doing SQL `select`, `update`, `insert` and
so on.

This mixture of methods is fine as long as one can be sure that a single phase does not use both approaches,
for the simple reason that datoms are immutable and the exact timing of read and write events within a
stream is left undefined. Therefore, when a regular stream transform reaches out to the database, in the
middle of processing, to change, add, or delete records, we can in no case alter datoms that have already
been read from the DB, and can never be sure whether our changes will be picked up by future DB read events.
Therefore, when a regular and a pseudo transform work side by side within the same phase, neither can be
sure about the changes effected by the other. To avoid this race condition, each phase can only ever only
modify the DB directly or work exclusively on the stream of datoms.

> NOTE discuss arrangements where this restriction may be relaxed, e.g. when all DB actions are restricted
> to the instantiation stage of a regular stream transform.



