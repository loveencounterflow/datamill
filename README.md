
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

# Development Outlook

At the time of this writing, DataMill is growing to become the next version and complete re-write
of [MingKwai TypeSetter 明快排字機](https://github.com/loveencounterflow/mingkwai-typesetter) and
at some point in time, it is planned to refactor code such that, in terms of dependencies, roughly the
following layers—from top to bottom—will emerge:

* **[MingKwai TypeSetter](https://github.com/loveencounterflow/mingkwai-typesetter)**—A text processor that
  translates from a MarkDown-like markup language to targets like TeX, PDF, and HTML; specifically geared
  towards processing and typesetting of CJK (Chinese, Japanese, Korean) script material retrieved from
  database queries.

* **[DataMill](https://github.com/loveencounterflow/datamill)**—A line-oriented multi-pass data processor
  backed by a relational (SQLite) DB that allows to generate new documents from collections of source texts.
  Document processing consists in a number of discrete *phases* that may both be looped and confined to
  parts of a document, thereby enabling the handling of recursive markup (like turning a file with a
  blockquote that contains markup from another file with a heading and a paragraph and so on).

* **[MKTS Mirage](https://github.com/loveencounterflow/mkts-mirage)**—Mirrors text files into a relational
  DB (SQLite) such that data extraction and CRUD actions—insertions, deletions and modifications—become
  expressable as SQL statements. The multi-layered vectorial index (a Vectorial Lexicographic Index
  implemented in [Hollerith](https://github.com/loveencounterflow/hollerith)) of Mirage makes it possible to
  keep line histories and source references while updating data and inserting and and re-arranging document
  parts while keeping all the data in its proper ordering sequence.

* **[ICQL](https://github.com/loveencounterflow/icql)**—A YeSQL adapter to organize queries against
  relational databases.

* **[Hollerith](https://github.com/loveencounterflow/hollerith)**—A facility to handle the definition of and
  arithmetics with Vectorial Lexicographic Indexes (VLXs) as well as their encoding into binary and textual
  forms such that even software not normally built to handle layered lexicographic sorting (such as
  JavaScript's simple-minded `Array#sort()`, any text editors `sort lines` command, or SQLites `order by
  blob`) can maintain the proper relative order of records. A particular interesting property of VLXs is
  akin to the ordering of rational numbers as described by Cantor when compared to integer numbers: Of both
  there are countably infinetely many, and one can always append or prepend arbitrarily many new elements to
  any sequence of existing elements. However, with a mere `rowid` integer index, there are no free positions
  left between, say, rows `9` and `10`, and adding more material in this spot necessitates renumbering all
  following rows. Vectorial indexes are like rational numbers in that there are infinetely many of them
  between any given two distinct values: `19/2`, `39/4` etc, or, in vectors, `[9,0] ... [9,1] ... [10,-1]
  ... [10,0] ... [10,1]` and so on.

* **[PipeDreams](https://github.com/loveencounterflow/pipedreams)**—A pipestreaming infrastructure designed
  to enable breaking down the processing of data streams into many small steps, laid out in a clear,
  quasi-linear plan (the pipeline). PipeDreams suggestes a standardized data shape—JS/JSON Objects with a
  `key`, some internal attributes like `$stamped` for book-keeping—called 'datoms' (shamelessly copied from
  [here](https://docs.datomic.com/cloud/whatis/data-model.html)) and arbitrary properties for the payload—XXX

# Details

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



