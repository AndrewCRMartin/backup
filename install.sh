SCRIPTS=$HOME/scripts
BIN=$HOME/bin

mkdir -p $SCRIPTS
mkdir -p $BIN

cp backup.pl $SCRIPTS
(cd $BIN; ln -s $SCRIPTS/backup.pl backup)

