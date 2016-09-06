#!/usr/bin/perl -s
#*************************************************************************
#
#   Program:    backup
#   File:       backup.pl
#   
#   Version:    V1.5
#   Date:       06.09.16
#   Function:   Flexible backup script
#   
#   Copyright:  (c) Dr. Andrew C. R. Martin, UCL, 2016
#   Author:     Dr. Andrew C. R. Martin
#   Address:    Institute of Structural and Molecular Biology
#               Division of Biosciences
#               University College
#               Gower Street
#               London
#               WC1E 6BT
#   EMail:      andrew@bioinf.org.uk
#               
#*************************************************************************
#
#   This program is not in the public domain, but it may be copied
#   according to the conditions laid out in the accompanying file
#   COPYING.DOC
#
#   The code may be modified as required, but any modifications must be
#   documented so that the person responsible can be identified. If 
#   someone else breaks this code, I don't want to be blamed for code 
#   that does not work! 
#
#   The code may not be sold commercially or included as part of a 
#   commercial product except as described in the file COPYING.DOC.
#
#*************************************************************************
#
#   Description:
#   ============
#   Flexible backup program to perform a backup from a set of direcories
#   to other directories. Each may be backed up to multiple destinations.
#   Also supports backups from PostgreSQL databases and to remote ssh 
#   hosts.
#   
#*************************************************************************
#
#   Usage:
#   ======
#
#*************************************************************************
#
#   Revision History:
#   =================
#   V1.0   12.08.16  Original   By: ACRM
#   V1.1   14.06.16  Added -delete and -nodelete options
#   V1.2   20.06.16  Added -c option
#   V1.3   30.08.16  Improved help
#   V1.4   05.09.16  Added --delete-excluded to rsync delete options
#   V1.5   06.09.16  Allows host:port for database specification
#                    Checks that pg_dumpall exists
#
#*************************************************************************
# Add the path of the executable to the library path
use FindBin;
use lib $FindBin::Bin;
# Or if we have a bin directory and a lib directory
#use Cwd qw(abs_path);
#use FindBin;
#use lib abs_path("$FindBin::Bin/../lib");

use strict;

# Usage message
UsageDie($::h) if(defined($::h));

# Constants
use constant QUIET       => 0;
use constant VERBOSE     => 1;
use constant NOCREATE    => 0;
use constant CREATE      => 1;
use constant IS_DIR      => 1;
use constant IS_FILE     => 0;
use constant DESTINATION => "Destination";
use constant SOURCE      => "Source";
use constant DELETE      => "--delete --delete-excluded";

# Configuration and options
my $configFile = SetConfigFile($FindBin::Bin, @ARGV);
my ($hDisks, $hExclude, $hDatabases) = ReadConf($configFile);
my $backupOptions = "-a --exclude=lost+found";
my $doDelete      = SetDeleteIfSunday();
$backupOptions   .= " -v" if(!defined($::q) && !defined($::qr));
$backupOptions   .= " -n" if(defined($::nr));

# Global variables
$::pgdump = "pg_dumpall"

CheckConfigAndDieOnError($hDisks, $hDatabases);

# Run!
if(defined($::init))
{
    InitBackupDirs($hDisks);
}
elsif(defined($::c))
{
    PrintLastBackups($hDisks);
}
else
{
    my $diskBackupErrors     = BackupDisks($hDisks, $hExclude, 
					   $backupOptions, $doDelete);
    my $databaseBackupErrors = BackupDatabases($hDatabases);

    if($diskBackupErrors)
    {
	print STDERR "\n\n*** ERROR BACKING UP DISKS: $diskBackupErrors missing distination directories\n\n";
    }
    if($databaseBackupErrors)
    {
	print STDERR "\n\n*** ERROR BACKING UP DATABASES: $databaseBackupErrors missing distination directories\n\n";
    }
}


#*************************************************************************
# UsageDie()
# ----------
# Prints a usage message
#
# 12.08.16  Original   By: ACRM
# 30.08.16  Added -h=config parameter
sub UsageDie
{
    my($example) = @_;

    if($example eq '1')
    {
        print <<__EOF;

Backup V1.5 (c) 2016 Dr. Andrew C.R. Martin, UCL

Usage: backup [-h[=config]][-n][-nr][-q][-v][-create][-init][-c]
              [-nodelete][-delete]     [backup.conf]
       -h        This help message
       -h=config Give details of config file
       -n        Pretend to do the backup
       -nr       Make rsync pretend to do the backup
       -q        Run quietly
       -qr       Make rsync run quietly
       -c        Check when backups were last done
       -create   Create destination directories if they do not exist
       -init     Initializes all directories and adds .runbackup file 
                 to each
       -delete   Force deletion of files on the backup if they have
                 gone away in the source directory even if it is not
                 Sunday.
       -nodelete Prevent deletion of files on the backup if they have
                 gone away in the source directory even if it is 
                 Sunday. (Takes precedent over -delete)
               

Backup is a flexible backup program for performing backups using
rsync.  It takes a config file which lists the directories to be
backed up and, for each, one or more destinations to which they are
backed up and one or more files/directories to be excluded. See the
rsync(1) documentation for the format for specifying these. It can
also back up local PostgreSQL databases - specify a port and one or
more files to dump the backup to.

By default the program only deletes files on the backup if they have
gone away in the source directory if the program is run on a Sunday.
The -delete/-nodelete options override this.

The configuration file may be specified on the command line. If not,
then the program will look for 'backup.conf' in the current directory
and, if not found, then will look for 'backup.conf' in the directory
where the backup program lives.

The program ensures that a file called '.runbackup' is present in 
both the source and destination directories. This ensures that 
a) a backup is not run to a destination that has gone away (e.g. 
not been mounted and therefore filling the wrong disk) and b) that 
the source has not gone away (potentially deleting the content of
the backup). Run with -init to create these files everywhere.
The time and date at which a backup is completed is also written
into the destination .runbackup file and is then checked when the
program is run with -c so you can quickly check when a backup was
last performed.

NOTE! rsync must be installed and in your path. pg_dumpall from the
PostgreSQL package must be available in your path if you wish to
backup databases. You can use the PGDUMP command under OPTIONS to
set this to something else.

__EOF
    }
    else
    {
        print <<'__EOF';
    
Example config file...

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
BACKUP /nas/backup/pg/5432.sql

__EOF
    }

    exit 0;
}

#*************************************************************************
# CheckConfigAndDieOnError(@configHashes)
# ---------------------------------------
# Checks the config data is valid - i.e. all destinations are full paths
#
# 12.08.16  Original   By: ACRM
sub CheckConfigAndDieOnError
{
    my (@configHashes) = @_;

    foreach my $hConfigHash (@configHashes)
    {
	foreach my $source (keys %$hConfigHash)
	{
	    my @destinations = @{$$hConfigHash{$source}};
	    foreach my $destination (@destinations)
	    {
		if(!($destination =~ /^\//))
		{
                    if($destination =~ /^(.*)\//)
                    {
                        my $host = $1;
                        if(!($host =~ /.*\@.*\//))
                        {
                            print STDERR "\n*** BACKUP CONFIG ERROR - all destination paths must start with a / ***\n\n";
                            exit 1;
                        }
                    }
                    else
                    {
                        print STDERR "\n*** BACKUP CONFIG ERROR - all destination paths must start with a / ***\n\n";
                        exit 1;
                    }
		}
	    }
	}
    }	
}


#*************************************************************************
# InitBackupDirs($hDisks)
# -----------------------
# Initialize backup directories. Checks source directories exist, creates
# destination directories if they don't exist. Places .runbackup file in
# each directory.
#
# 12.08.16  Original   By: ACRM
sub InitBackupDirs
{
    my ($hDisks) = @_;

    foreach my $source (keys %$hDisks)
    {
	my $theSource = $source;

	# Add / to end of source if missing
	$theSource .= '/' if(!($theSource =~ /\/$/));  
	if(!CheckExists($theSource, 0, IS_DIR, NOCREATE, VERBOSE, SOURCE))
	{
	    exit 1;
	}

	$theSource .= ".runbackup"; 
	RunExe("touch $theSource");

	my @destinations = @{$$hDisks{$source}};
	foreach my $destination (@destinations)
	{
	    my $theDestination = $destination;

	    # Add / to end of destination if missing
	    $theDestination .= '/' if(!($theDestination =~ /\/$/));
	    CheckExists($theDestination, 0, IS_DIR, CREATE, 
			VERBOSE, DESTINATION);

	    $theDestination .= ".runbackup"; 
	    RunExe("touch $theDestination");
	}
    }
}


#*************************************************************************
# $totalErrors = BackupDatabases($hDatabases)
# -------------------------------------------
# Run all PostgreSQL database backups
#
# 12.08.16  Original   By: ACRM
sub BackupDatabases
{
    my($hDatabases) = @_;
    my $totalErrors = 0;
    foreach my $database (keys %$hDatabases)
    {
	my $errors;
	$errors = RunDatabaseBackup($database, $$hDatabases{$database});
	$totalErrors += $errors;
    }

    return($totalErrors);
}

#*************************************************************************
# $errors = RunDatabaseBackup($database, $aDestinations)
# ------------------------------------------------------
# Run a PostgreSQL database backup
#
# 12.08.16  Original   By: ACRM
# 06.09.16  Now allows databases to be specified as host:port rather than
#           just the port
sub RunDatabaseBackup
{
    my($database, $aDestinations) = @_;
    my $errors = 0;
    my $host   = 'localhost';
    my $port   = 5432;

    if(! -x $::pgdump)
    {
        print STDERR "\n\n*** ERROR BACKING UP DATABASES: $::pgdump not available\n";
        return(0);
    }

    if($database =~ /\:/)
    {
        ($host, $port) = split(/\:/, $database);
    }
    else
    {
        $port = $database;
    }


    foreach my $destination (@$aDestinations)
    {
	print STDERR ">>> Backing up PostgreSQL database on port $database to $destination...\n" if(!defined($::q));

	if(CheckExists($destination, 1, IS_DIR, $::create, 
		       VERBOSE, DESTINATION))
	{
	    my $exe = "su - postgres -c \"$::pgdump --port=$port --host=$host >$destination\"";
            RunExe($exe);
        }
	else
        {
	    $errors++;
        }
    }
    return($errors)
}


#*************************************************************************
# $totalErrors=BackupDisks($hDisks, $hExclude, $backupOptions, $doDelete)
# -----------------------------------------------------------------------
# Run all disk backups
#
# 12.08.16  Original   By: ACRM
sub BackupDisks
{
    my($hDisks, $hExclude, $backupOptions, $doDelete) = @_;
    my $totalErrors = 0;

    foreach my $source (keys %$hDisks)
    {
	my $errors;
        my @excludes = ();
        if(defined($$hExclude{$source}))
        {
            push @excludes, @{$$hExclude{$source}};
        }
        if(defined($$hExclude{'ALL'}))
        {
            push @excludes, @{$$hExclude{'ALL'}};
        }

	$errors = RunDiskBackup($source, 
				\@excludes,
				$$hDisks{$source}, 
				$backupOptions, $doDelete);
	$totalErrors += $errors;
    }

    return($totalErrors);
}


#*************************************************************************
# $errors = RunDiskBackup($source, $aExcludes, $aDestinations,
#                         $backupOptions, $doDelete)
# ------------------------------------------------------------
# Run the backup of a disk. Checks the source and destination exist
# and contain the .runbackup file (used to ensure the directory hasn't
# been inmounted).
#
# 12.08.16  Original   By: ACRM
sub RunDiskBackup
{
    my($source,$aExcludes,$aDestinations,$backupOptions,$doDelete) = @_;
    my $errors = 0;

    # Add / to end of source if missing
    $source .= '/' if(!($source =~ /\/$/));  

    my $exclude = '';
    foreach my $excl (@$aExcludes)
    {
	$exclude .= "--exclude=$excl ";
    }

    if(CheckExists($source, 0, IS_DIR, NOCREATE, VERBOSE, SOURCE))
    {
	if(CheckExists($source.".runbackup", 0, IS_FILE, NOCREATE, 
		       QUIET, SOURCE))
	{
	    foreach my $destination (@$aDestinations)
	    {
		if(CheckExists($destination, 0, IS_DIR, $::create, 
			       VERBOSE, DESTINATION))
		{
                    my $theDestination = $destination;
                    $theDestination .= "/" if(!($destination =~ /\/$/));
                    if(CheckExists($theDestination.".runbackup", 0, IS_FILE, $::create, 
                                   QUIET, DESTINATION))
                    {
                        print STDERR ">>> Backing up $source to $destination\n" if(!defined($::q));
                        my $exe = "rsync $backupOptions $doDelete $exclude $source $destination";
                        RunExe("$exe");

                        # Touch the runbackup file on the destination so we can check when a 
                        # backup was last run.
                        $exe = "date > $destination/.runbackup";
                        RunExe("$exe");
                    }
                    else
                    {
                        print STDERR "*** INFO: Backup skipped since .runbackup file doesn't exist in $destination\n";
                    }
		}
		else
		{
		    $errors++;
		}
	    }
	}
	else
	{
	    print STDERR "*** INFO: Backup skipped since .runbackup file doesn't exist in $source\n";
	}
    }

    return($errors);
}

#*************************************************************************
# RunExe($exe)
# ------------
# Runs a given command. 
# Checks the global $::n to see whether only to print the command rather 
# than run it.
# Checks the global $::v to see whether to print the command when it is
# being run.
#
# 12.08.16  Original   By: ACRM
sub RunExe
{
    my($exe) = @_;

    if(defined($::n) || defined($::v))
    {
	print "$exe\n";
    }

    if(!defined($::n))
    {
	system($exe);
    }
}

#*************************************************************************
# $ok = CheckExists($dir, $parent, $isdir, $create, $verbose, $type)
# ------------------------------------------------------------------
# Input:   $dir     - Directory or file to check
#          $parent  - Number of parent levels to look at above $dir
#          $isDir   - Is this a file or directory (IS_DIR|IS_FILE)
#          $create  - Create the directory if missing? (CREATE|NOCREATE)
#          $verbose - Give message if dir/file is missing? (VERBOSE|QUIET)
#          $type    - Is this a source or destination - used with
#                     $verbose=VERBOSE (DESTINATION|SOURCE)
#
# Checks if a directory or file exists with options to give a message if
# is doesn't and to create a directory if it is missing. Can also look
# at parents of the specified file/directory.
#
# 12.08.16  Original   By: ACRM
sub CheckExists
{
    my($dir, $parent, $isdir, $create, $verbose, $type) = @_;

    if($type eq DESTINATION)
    {
        if((!($dir =~ /^\//)) && # It's not a local path
           ($dir =~ /\@.*:\//))  # It does have a x@y:/ remote path
        {
            return(1);
        }
    }

    if($parent)
    {
	$dir =~ s/\/$//;  # Remove trailing /
	my @fields = split(/\//, $dir);
	$dir = '/';
	for(my $i=1; $i<scalar(@fields) - $parent; $i++)
	{
	    $dir .= $fields[$i] . '/';
	}
    }

    if(($isdir  && (-d $dir)) ||
       (!$isdir && (-f $dir)))
    {
	return(1);
    }

    if($create)
    {
	print STDERR "*** BACKUP INFO - Creating $type directory: $dir\n";
	system("mkdir -p $dir");
	if(!(-d $dir))
	{
	    print STDERR "*** BACKUP FATAL - Could not create $type directory: $dir\n";
	    exit 1;
	}
	return(1);
    }
    elsif($verbose)
    {
	print STDERR "*** BACKUP FAILED - $type directory does not exist: $dir\n";
    }

    return(0);
}

#*************************************************************************
# $delete = SetDeleteIfSunday()
# -----------------------------
# We will only delete files from the backup on a Sunday night
# This gives people a chance to recover accidentally deleted
# files during the week
#
# 12.08.16  Original   By: ACRM
# 15.06.16  Now checks the command line for -delete -nodelete
sub SetDeleteIfSunday
{
    my $delete = ' ';
    my $day = substr(localtime, 0, 3);
    if(defined($::nodelete))
    {
	$delete = '';
    }
    elsif(defined($::delete))
    {
	$delete = DELETE;
    }
    elsif($day eq 'Sun')
    {
	$delete = DELETE;
    }
    return($delete);
}


#*************************************************************************
# ($hDisks, $hExclude, $hDatabases) = ReadConf($backupFile)
# ---------------------------------------------------------
# Read the configuration file
#
# 12.08.16  Original   By: ACRM
sub ReadConf
{
    my($confFile) = @_;

    my $source    = '';
    my $db        = '';
    my $options   = '';
    my %disks     = ();
    my %exclude   = ();
    my %databases = ();

    if(open(my $fp, '<', $confFile))
    {
	while(<$fp>)
	{
	    chomp;
	    s/\#.*//;    # Remove comments
	    s/^\s+//;    # Remove leading spaces
	    if(length)
	    {
		if(/^DISK\s+(.*)/)
		{
		    $source  = $1;
		    $db      = '';
                    $options = 0;
		}
		elsif(/^DATABASE\s+(.*)/)
		{
		    $source  = '';
		    $db      = $1;
                    $options = 0;
		}
		elsif(/^OPTIONS/)
		{
		    $source  = '';
		    $db      = '';
                    $options = 1;
		}
		elsif(/^BACKUP\s+(.*)/)
		{
		    if($source ne '')
		    {
			push(@{$disks{$source}}, $1);
		    }
		    elsif($db ne '')
		    {
			push(@{$databases{$db}}, $1);
		    }
		}
		elsif(/^EXCLUDE\s+(.*)/)
		{
                    if($source ne '')
                    {
                        push(@{$exclude{$source}}, $1);
                    }
                    elsif($options)
                    {
                        push(@{$exclude{'ALL'}}, $1);
                    }
		}
                elsif($options && /^PGDUMP\s+(.*)/)
                {
                    $::pgdump = $1;
                }
	    }
	}
    }
    else
    {
	print STDERR "\n***BACKUP FATAL - Unable to read configuration file: $confFile\n\n";
	exit 1;
    }

    return(\%disks, \%exclude, \%databases);
}


#*************************************************************************
# $configFile = SetConfigFile($FindBin::Bin, @ARGV)
# -------------------------------------------------
# Return the name of a config file. Priority is:
# 1. Anything given in $ARGV[0]
# 2. backup.conf in the current directory
# 3. backup.conf in the directory where this script lives
#
# 12.08.16  Original   By: ACRM
sub SetConfigFile
{
    my($binDir, @argv) = @_;
    my $configFile = '';

    if(scalar(@argv))
    {
	$configFile = $argv[0];
    }
    elsif(-f './backup.conf')
    {
	$configFile = './backup.conf';
    }
    else
    {
	$configFile = "$binDir/backup.conf";
    }

    if(!(-f $configFile))
    {
	printf STDERR "\n*** BACKUP FATAL - Configuration file not found: $configFile\n\n";
	exit 1;
    }

    return($configFile);
}


#*************************************************************************
# PrintLastBackups($hDisks)
# -------------------------
# Prints times at which the last backups were run based on the .runbackup
# files in the destination directories.
#
# 12.08.16  Original   By: ACRM
sub PrintLastBackups
{
    my ($hDisks) = @_;

    foreach my $source (keys %$hDisks)
    {
	my @destinations = @{$$hDisks{$source}};
	foreach my $destination (@destinations)
	{
	    my $theDestination = $destination;
            $theDestination .= "/" if(!($theDestination =~ /\/$/));
	    $theDestination .= ".runbackup"; 
            print "$source -> $destination\n   ";
	    RunExe("cat $theDestination");
            print "\n";
	}
    }
}


