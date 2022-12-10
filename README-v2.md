

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

* WARC is in principle interesting but tool support seems clunky, not even
  [ReplayWeb.page](https://github.com/webrecorder/replayweb.page) ([online version](https://replayweb.page))
  seems to support faithful rendering (but might work with unpacking files?)

## Glossary

* **FAD**: **F**ile **AD**apter, an object that implements the file adapter API using methods such as
  `fad.walk_lines()`, `fad.walk_chunks()`, `fad.walk_export()` and so on. 


   
