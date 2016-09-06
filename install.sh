#!/bin/bash

SCRIPTS=$1
BIN=$2

DEFSCRIPTS=$HOME/scripts
DEFBIN=$HOME/bin

# Aborted install - Print a message on how to get help
AbortInstall ()
{
   echo ""
   echo "Install aborted. Type "
   echo ""
   echo "   ./install -h"
   echo ""
   echo "for help on how to specify the destinations."
   echo ""
   exit 1;
}

# Help Message
PrintHelp ()
{
   echo ""
   echo "backup install script V1.4 (c) UCL, Dr Andrew C R Martin"
   echo ""
   echo "Usage: ./install.sh [scriptsdir [bindir]]"
   echo ""
   echo "By default, the Perl script will be installed in \$HOME/scripts and a"
   echo "link will be provided in \$HOME/bin"
   echo ""
   echo "This can be overridden by specifying the script directory followed"
   echo "(optionally) by the binary directory on the command line."
   echo ""
   echo "For example, to install the script in /usr/local/apps/backup and a"
   echo "link in /usr/local/bin, you would do"
   echo ""
   echo "   ./install.sh /usr/local/apps/backup  /usr/local/bin"
   echo ""
   echo "If you want to keep the script in this directory where you unpacked"
   echo "the program, then just do"
   echo ""
   echo "   ./install.sh .  /usr/local/bin"
   echo ""
}

# Check command line for '-h' - help
if [ "X$SCRIPTS" == "X-h" ]; then
    PrintHelp;
    exit 0
fi

# Check command line for script dir being specified
if [ "X$SCRIPTS" == "X" ]; then
   SCRIPTS=$DEFSCRIPTS
fi

# Check command line for binary dir being specified
if [ "X$BIN" == "X" ]; then
   BIN=$DEFBIN
fi

# Check for pre-existing files and allow user to abort
if [ -e "$SCRIPTS/backup.pl" ]; then
    echo -n "$SCRIPTS/backup.pl exists already. Overwrite? (Y/N) [Y]: "
    read yorn
    if [ "X$yorn" == "XN" ] || [ "X$yorn" == "Xn" ]; then
        AbortInstall;
    fi
fi

if [ -e "$BIN/backup" ]; then
    echo -n "$BIN/backup exists already. Overwrite? (Y/N) [Y]: "
    read yorn
    if [ "X$yorn" == "XN" ] || [ "X$yorn" == "Xn" ]; then
        AbortInstall;
    fi
fi

# Install the script if it's not to go in the current directory
if [ "X$SCRIPTS" != "X." ]; then
    mkdir -p $SCRIPTS
    cp backup.pl $SCRIPTS
    echo "The script has been installed in $SCRIPTS"
else
    echo "The current directory was specified for the script so nothing was copied."
fi

# Install the link
echo "A link called 'backup' has been provided in $BIN"
mkdir -p $BIN
(cd $BIN; ln -sf $SCRIPTS/backup.pl backup)

