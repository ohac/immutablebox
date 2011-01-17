Immutablebox
============

A Dropbox clone.

* Manage small and big files.
* Sync files with other directories.
* Store files as many pieces like BitTorrent.
* Replicate pieces to other directories.
* You can choose directories as you like. (NFS, Samba, FUSE(FTP, WebDAV), ...)

Installation
------------

TODO

* `gem install immutablebox`

Usage
-----

* `ib commit` commit all outstanding changes
* `ib init` create a new repository in the given directory
* `ib log` show revision history of entire repository
* `ib status` show changed files in the working directory
* `ib update` update working directory (or switch revisions)

Below are not implemented yet.

* `ib pull` pull changes from the specified source
* `ib push` push changes to the specified destination
* `ib replicate` replicate pieces with other repository
* `ib verify` verify all pieces of the repository

Tutorial
--------

* `mkdir MyBox`
* `cd MyBox`
* `ib init`
* `mv ../YourFolder1 ../YourFile.txt .`
* `ib commit`
* `ib log`
* `vi YourFile.txt`
* `ib status`
* `ib commit`
* `ib log`
* `rm YourFile.txt`
* `ib status`
* `ib update`
* `vi YourFile.txt`
