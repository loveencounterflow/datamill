

# DataMill V2


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [DataMill V2](#datamill-v2)
  - [File Formats](#file-formats)
  - [Glossary](#glossary)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->



# DataMill V2


## File Formats

* SQLite DB file with BLOBs; may also reference external files where embedding is deemed a bad idea

* rendered document single file with inline `data` URLs; this is the same format as used by
  [SingleFile](https://github.com/gildas-lormeau/SingleFile); should also support optional external files
  (maybe only when viewed with local web server)
  * works out-of-the-box with browsers
  * [SingleFile](https://github.com/gildas-lormeau/SingleFile) could be the recommended / pre-installed
    software to import documents directly from the web, including media files

* WARC is in principle interesting but tool support seems clunky, not even
  [ReplayWeb.page](https://github.com/webrecorder/replayweb.page) ([online version](https://replayweb.page))
  seems to support faithful rendering (but might work with unpacking files?)

* A DataMill document is
  * in the simplest case, a single SQLite DB file, or
  * a collection of source files, presumably collected in a single folder
    * source files can be external or internal (WRT the central SQLite DB file);
      * external files are referenced by absolute and relative URLs (references to local FS, network, or the
        Internet); when the document core files are sent to another machine and external files are missing,
        the document can not be reconstructed completely (but see self-containing exported files)
      * internal files are stored inside the DB as lines of texts or BLOB chunks; they may optionally still
        reference external resources so can be re-synchronized
  * potentially, an application that may have its own executables, `node_modules` folder, `npm`-updatable
    dependencies.
  * still looking for an appropriate generic bundling format that allows to treat contents both as a
    monolithic file and a folder hierarchy
    * SquashFS, UnionFS: probably too obscure, 'insiders-only' style documentation, quite
      systems-programming oriented
    * [SQLite Archives](https://www.sqlite.org/sqlar.html)

## Glossary

* **FAD**: **F**ile **AD**apter, an object that implements the file adapter API using methods such as
  `fad.walk_lines()`, `fad.walk_chunks()`, `fad.walk_export()` and so on. 


   
