
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
  JavaScript's simple-minded `Array#sort()`, any text editor's `sort lines` command, or SQLite's `order by
  blob`) can maintain the proper relative order of records. A particular interesting property of VLXs is
  akin to the ordering of rational numbers (as famously described by Cantor) when compared to integer
  numbers: Of both there are countably infinitely many, and one can always append or prepend arbitrarily
  many new elements to any sequence of existing elements. However, with a mere `rowid` integer index, there
  are no free positions left between, say, rows `9` and `10`, and adding more material in this spot
  necessitates renumbering all following rows. Vectorial indexes are like rational numbers in that there are
  *infinitely many of them even between any given two distinct values*: `10/1 < 19/2 < 39/4 < 10` etc, or,
  in vectors, `[9,0] < [9,1] < [10,-1] < [10,0] < [10,1]` and so on. VLXs don't have to be purely numeric,
  as Hollerith imposes an absolute ordering over all possible arrays of numbers, texts, booleans and dates.

* **[PipeDreams](https://github.com/loveencounterflow/pipedreams)**—A pipestreaming infrastructure designed
  to enable breaking down the processing of data streams into many small steps, laid out in a clear,
  quasi-linear plan (the pipeline). PipeDreams proposes a standardized data shape—JS/JSON Objects with a
  `key`, some internal attributes like `$stamped` for book-keeping and arbitrary properties for the
  payload—as well as a set of standard operations. These 'datoms' (a name shamelessly copied from
  [here](https://docs.datomic.com/cloud/whatis/data-model.html)) are *immutable* (deeply frozen) which is
  why handling them can be done with confidence (because you can be reasonably sure no-one down the
  processing line will modify the data value you've just acted upon: a fact is a fact).

# Parts of Processing

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

## Repetition

## Reprise

## Stamping

> i.e. decommissioning of rows

## Row Insertion

> two ways, 'locally' by `recede deepen d`, non-locally by finding the successor of the current line's
> predecessor with same prefix.

## Realms (RLM)

A 'domain' of processing in the sense that when running a group of phases over a document, typically only
rows belonging to a given, single realm are considered. The initial realm of a document that has just been
read in By MKTS Mirage is named `input`. A new realm is created for a specific purpose (e.g. an output
format) by copying (a subset of unstamped) rows from an existing domain.

For example, assume that a file has been read into RLM `input` and processed to a certain degree, and that
one wants to produce an HTML page from it. Turning a preprocessed line into HTML entails interpolating
suitable tags into the source, so one has to modify rows or use the stamp/insert approach to insert new
content. Either way, the state of the preprocessed material is changed, so if we wanted to also produce a
TeX output for a PDF version from the same source, we would have to either base *that* transformation on the
HTML output or else recompute the entire input up to a certain stage anew. Using realms, one can essentially
freeze the result of one set of transforms in realm `A`, copy whatever data is needed to a new realm `B`,
and then apply a new set of transforms exclusively on rows belonging to `B`. Later, a derivation from the
unaltered realm `A` may be applied to obtain another reansformation, `C`.

# Parts of Documents


## Vectorial Line Number (VNR)

> Line numbers as vectors; see project overview and Hollerith / Hollerith Codec docs.


## Source (SRC)

> All source files get a numerical index and a path. As line numbers (and, by extension, vectorial line
> numbers (VNRs)) are only locally valid, meaningful and unique (that is, within a given file), VNRs have to
> be extended by source IDs for global use.

## Pieces (PCE)

Having established that line numbers have to be combined with source IDs (SRCs) to make them globally
unique, we now observe that—apart from uniqueness—another indispensable property—namely, relative ordering
in the target document—cannot be achieved with `(SRC,VNR)` vectors. The only ordering that `(SRC,VNR)`
vectors support for any two given documents `a`, `b` is `a[1], ... a[n], b[1], ... b[m]` (and the reverse
arrangement where `b` comes first), i.e. concatenation. That is clearly not good enough if we want to be
able to insert a file `b` in the middle of a containing file `a`. This is where **pieces** (PCE) come in. By
prepending an PCE counter to the Lexicographic Index, we get `(PCE,SRC,VNR)` and we now can represent
sequences of embedding and embedded lines unambiguously and in an order-preserving manner:

```
 (PCE,SRC,VNR)
 (1,5,1) first line of file #5
 (1,5,2)
 (1,5,3)
*(1,5,4) <insert src=1/>

 (2,1,1) first line of file #1
 (2,1,2)
 (2,1,3) last line of file #1

 (3,5,5) line #5 of file #5
 (3,5,6)
 (3,5,7)
 (3,5,8) last line of file #5
```


## Deck (DCK)

Apart from the more obvious parts of paper-based and digital documents such as chapters, sections and
paragraphs, there are also the less obvious but equally important and, crucially, mandatorily arranged
'functional' parts.

For example, a book may have a title page, a CIP notice, a preface, a table of contents, a main part, an
index and so on, all of which should appear in a fixed order. Some of these have fixed lengths, such as the
single page that shows cataloging data and the publisher's copyright notice; others, like the index, the TOC
and the table of figures wax and wane as the document is getting read and processed line by line.

As for digital documents, HTML pages have, inter alia, a preparatory part demarcated by `<head> ... </head>`
tags, and a main part demarcated by `<body> ... </body>` tags. Likewise, in a LaTeX source file, some
commands like `\\usepackage{xy}` and `\\newcommand{uvw}{...}` may only appear in the document preamble; once
the preamble has been closed with `\\begin{document}`, such preparatory commands are no longer allowed.

In all three cases, it is often convenient to allow authors to declare resources needed for a particular
part of the project at the point where, when and if that part comes up for processing.

With decks, it is possible to stipulate that a given portion of the source should be prepended or appended
to a designated target area of the target.


## DataMill Primary Key

`( RLM, DCK, LYR, SRC, VNR)`





