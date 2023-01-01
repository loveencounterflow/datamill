

# DataMill V2


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [DataMill V2](#datamill-v2)
  - [File Formats](#file-formats)
  - [Glossary](#glossary)
  - [Todo](#todo)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->



# DataMill V2


## File Formats

* rendered document single file with inline `data` URLs; this is the same format as used by
  [SingleFile](https://github.com/gildas-lormeau/SingleFile); should also support optional external files
  (maybe only when viewed with local web server)
  * works out-of-the-box with browsers
  * [SingleFile](https://github.com/gildas-lormeau/SingleFile) could be the recommended / pre-installed
    software to import documents directly from the web, including media files

* Plan for the DataMill Document Format (DMDF):
  * A DataMill document is
    * a collection of source files, presumably collected in a single folder
      * source files can be external or internal (WRT the central SQLite DB file);
        * external files are referenced by absolute and relative URLs (references to local FS, network, or
          the Internet); when the document core files are sent to another machine and external files are
          missing, the document can not be reconstructed completely (but see self-containing exported files)
        * internal files are stored inside the DB as lines of texts or BLOB chunks; they may optionally
          still reference external resources so can be re-synchronized
      * potentially, an application that may have its own executables, `node_modules` folder, `npm`-updatable
        dependencies.
    * an SQLite DB is used to build the output from the input files
      * this DB is seen as a useful but intermediate format
  * still looking for an appropriate generic bundling format that allows to treat contents both as a
    monolithic file and a folder hierarchy
    * <del>WARC</del>: is in principle interesting but tool support seems clunky, not even
      [ReplayWeb.page](https://github.com/webrecorder/replayweb.page) ([online
      version](https://replayweb.page)) seems to support faithful rendering (but might work with unpacking
      files?)
    * <del>SquashFS, UnionFS</del>: probably too obscure, 'insiders-only' style documentation, quite
      systems-programming oriented
    * <del>[SQLar (SQLite Archives)](https://www.sqlite.org/sqlar.html)</del>: similar to ZIP archives, but
      using an SQLite DB to store contents. Possible advantages over just using a ZIP archive could include
      extensibility of that DB (which consists of a single table with one index), e.g. adding content hashes
      etc. The utility is simple to build on Linux yet is a bit obscure, so probably not a good option
      (would necessitate building the `sqlar` utility on the target system where other options are either
      bundled with the OS or are easy to procure)
    * <del>[SQLarfs (SQLite Archives w/ Fuse)](https://www.sqlite.org/sqlar.html)</del>: provides read-only
      filesystem for an `*.sqlar` archive; write access is a must tho
    * [Fossil](https://fossil-scm.org)
      * a somewhat-popular version management system from the same people who created SQLite
      * they're using it themselves so as long as SQLite is an option, presumably Fossil will be available,
        too
      * free and open source, generous license
      * binary downloads available for Linux x64, Mac ARM, Mac x64, RaspberryPi, Windows32, Windows64, and
        as Source
      * can use existing DBay to obtain high-level access to repo meta data, raw data
    * conclusion: one may use Fossil or Git or another version control system to manage one's DataMill
      documents, as seen fit; this is external to DataMill (although routines to export/import documents may
      be provided)
  * also see [*The decades long quagmire of encapsulated
    HTML*](https://www.russellbeattie.com/notes/posts/the-decades-long-html-bundle-quagmire.html)

<!--

update config set value = $project_name where name = "project-name";

-->


## Glossary

* **FAD**: **F**ile **AD**apter, an object that implements the file adapter API using methods such as
  `fad.walk_lines()`, `fad.walk_chunks()`, `fad.walk_export()` and so on. 


## Todo

* **[–]** allow live-reloading on server
* **[–]** allow auto-reloading on client
* **[–]** allow to open document w/out specific location; use random / temporary directory (as with DBay)
* **[–]** validate regions created by loc markers (stop must not come before end &c)
* **[–]** consider to rename loc markers so they include the relevant doc_file_id
* **[–]** consider to insert `*` location marker; this would be helpful to find where an embedded document
  appears; however, that would also clash with `<!DOCTYPE html>` which is required to appear first thing
   
