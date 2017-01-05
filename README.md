backup
======

(c) 2016 UCL, Dr. Andrew C.R. Martin

A flexible backup script for Unix/Linux systems driven by a
configuration file. Allows backups from a directory to another
directory (typically remotely mounted), via SSH or via the `rsync`
protocol.  It makes use of `rsync` to perform the actual
backups. `backup` can also perform backups of PostgreSQL databases.

`backup` is driven by a configuration file which specifies the
directories to be backed up and the location(s) to which each
directory should be backed up. By default, files in the backup are not
deleted unless it is a Sunday when the program is run.

Obviously `backup` needs permissions to read the directories being
backed up, so normally it would be run as root. To backup databases,
the code must be run as root, or alternatively the PostgreSQL
superuser (normally 'postgres') must not have a password for read
access to all databases.

Program Installation
--------------------

To install the program in your local directory, simply type

```
   ./install.sh
```

This will install the Perl script in `$HOME/scripts` (as `backup.pl`)
and a link will be provided in `$HOME/bin` (as `backup`).

This can be overridden by specifying the script directory followed
(optionally) by the binary directory on the command line.

For example, to install the script in `/usr/local/apps/backup` and a
link in `/usr/local/bin`, you would do

```
   ./install.sh /usr/local/apps/backup  /usr/local/bin
```

If you want to keep the script in the directory where you unpacked
the program, then just do

```
   ./install.sh .  /usr/local/bin
```


Configuration File
------------------

The configuration file may contain comments introduced by a # sign at
any point.

The configuration file has three sections:

* An `OPTIONS` section to define global options
* A `DISK` section to define disks to be backed up
* A `DATABASE` section to define databases to be backed up

### OPTIONS

The `OPTIONS` section defines global settings. Currently the following
settings are supported:

1. `EXCLUDE` is used to define patterns for files that should be
excluded from all backups. Typically this might be used to exclude
editor backup files, compiler object files, etc. Multiple `EXCLUDE`
records may be specified. A typical setting would be:

        EXCLUDE **/*~
        EXCLUDE *.o
The pattern syntax is as used by `rsync`.

2. `PGDUMP` is used to specify the location of the PostgreSQL
`pg_dumpall` program. e.g.

        PGDUMP /usr/local/bin/pg_dumpall
If not specified, it is assumed that `pg_dumpall` is available in the
standard path.

3. `PGSUPERUSER` is used to specify the PostgreSQL superuser. This
defaults to `postgres`. e.g.

        PGSUPERUSER johnsmith

4. `PGNOSU` is used to change the way that the `pg_dumpall` program is
run. e.g.

        PGNOSU
By default, the script uses the `su` command to become the PostgreSQL
superuser. This means that the script must be run as root (since
otherwise a password would be needed to change user). It also means
that the directory where the database backup is placed must be
writable by the PostgreSQL superuser.<br />
If `PGNOSU` is specified, then the script doesn't change to run as the
PostgreSQL superuser, but instead simply runs the `pg_dumpall` program
specifying that the dump should be done as the PostgreSQL superuser
(with the `--user` option). This does not require that `backup` is run
by root or that the destination directory is writable by the
PostgreSQL superuser. However it does require that the PostgreSQL
superuser is not password protected in the database.

5. `RSYNCPW` is used to set a password for a remote rsync daemon. This
is only used if you are doing backups to a remote rsync daemon rather
than local disks or to a remote server over ssh. Currently only one
password may be specified and consequently you would normally be
backing up to a single remote rsync daemon server. e.g.

        RSYNCPW rsync


### DISK

The `DISK` section is the main section specifying directories to be
backed up and the locations to which they should be sent. There may be
multiple `DISK` sections.

Each section begins with a `DISK` command followed by the directory to
be backed up. This is then followed by one or more `BACKUP` commands
followed by the destination to which the files should be sent.


```
   DISK /data
   BACKUP /nas/backup/data
   BACKUP user@remotehost1:/backup/data
   BACKUP user@remotehost2::backup/data
```

This specifies that the directory `/data` should be backed up to three
locations: 

1. the locally mounted folder `/nas/backup/data`

2. via SSH to `/backup/data` as the specified user on the specified remote
machine. Note the single colon followed by a slash (`:/`).

3. via the RSYNC DAEMON to `backup/data` as the specified user on the
specified remote machine. Note the double colon followed by NO slash
(`::`). This is a 'short directory' name as specified in the rsync
daemon configuration file on the remote host.

Optionally, one or more `EXCLUDE` commands may be used to exclude
patterns from the backup. This works in the same way as the `EXCLUDE`
command in the `OPTIONS` section, but is restricted to this particular
disk's backups.

**Note** The `DISK` command is used to specify a directory whose
contents are to be backed up. With `rsync`, you need to add a / to the
end of the directory for this to happen (otherwise with `rsync` the
specified directory and its contents will be backed up). Adding a / to
the end of the directory name will not change the behaviour of
`backup`.

### DATABASE

The database section works in the same way as the `DISK` section.

The `DATABASE` command introduces a  `DATABASE` section and is followed by the port number to be backed up optionally preceded by the host followed by a colon. For example:

```
   DATABASE 5432
```

--or--

```
   DATABASE localhost:5432
```

This is followed by one or more `BACKUP` commands which specify a
backup file. e.g.

```
   BACKUP /nas/backup/pg/myhost_5432.sql
```

**Note 1** The destination backup directory (in this case
`/nas/backup/pg`), must be writable by the PostgreSQL superuser.

**Note 2** Remote backups over SSH are not currently supported.
However, you can always run a standard file-type backup of an SQL
backup to a remote host.

#### Example configuration file

```
   # Set global excludes
   OPTIONS
   EXCLUDE **/*~                         # Exclude anything that ends in a ~
   PGDUMP  /usr/local/bin/pg_dumpall     # Full specification for pg_dumpall
   
   # Backup /home/
   DISK   /home
   BACKUP /localbackup/home
   BACKUP /nas/backup/home
   
   # Backup /data/
   DISK    /data
   BACKUP  /nas/backup/data              # Backup locally
   BACKUP  user@remotehost:/backup/data  # Backup over ssh
   EXCLUDE tmp/                          # Exclude any tmp directories
   
   # Backup PostgreSQL database on the local host on port 5432
   DATABASE localhost:5432
   BACKUP   /nas/backup/pg/myhost_5432.sql
```

Initialization
--------------

`backup` takes a cautious approach to performing backups. To do this,
it keeps a file called `.runbackup` in each source directory and in
each destination directory. This ensures that no "backup" is
performed if either the source or destination directory has been
unmounted.

You can create these files manually - you can simply type, for example

```
   touch /data/.runbackup
   touch /nas/backup/data/.runbackup
```

(Note that no such file is needed for backups over SSH.)

Having created your configuration file, you can simply type:

```
   backup -init
```

to create all the destination directories and `.runbackup` files
automatically.

Invoking the program
--------------------

By default, `backup` will look for a file called `backup.conf` in the
current directory. Failing that it will look for `backup.conf` in the
directory where the program itself lives. Normally, however, you run
`backup` by specifying the configuration file on the command line:

```
   backup mybackup.conf
```

Typically you will want to run nightly backups from a cron job, so on
a Linux machine, you would create a script in your `/etc/cron.daily`
directory containing something like:

```
   DATE=`date +%F`
   LOG=/var/tmp/backup.$DATE
   /path/to/backup /path/to/backup.conf > $LOG
```

Further help
------------

Further help may be obtained by typing

```
   backup -h
```

