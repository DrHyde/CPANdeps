#!/bin/sh

DIR=`echo $0|sed 's/\/getfiles.sh//'`

echo Fetching 02packages ...

wget -q -O 02packages http://cpan.org/modules/02packages.details.txt.gz &&
mv 02packages 02packages.details.txt.gz

echo Fetching CPAN-testers database ...
wget -q -O barbiesdb.gz.tmp http://devel.cpantesters.org/cpanstats.db.gz &&
mv barbiesdb.gz.tmp barbiesdb.gz &&
gzip -fd barbiesdb.gz &&
./mangledb.pl

./populate-cache.pl
./build-reverse-index.pl

rm 02packages.details.txt.gz

echo
echo
echo Unknown OSes
echo
echo select \* from cpanstats where os = \'Unknown OS\'\;|./dbish 2>/dev/null
