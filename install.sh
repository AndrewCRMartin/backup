SCRIPTS=$HOME/scripts
BIN=$HOME/bin

mkdir -p $SCRIPTS
mkdir -p $BIN

cp backup.pl $SCRIPTS
(cd $BIN; ln -sf $SCRIPTS/backup.pl backup)

