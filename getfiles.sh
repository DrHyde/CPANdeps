#!/bin/sh

DIR=`echo $0|sed 's/\/getfiles.sh//'`

cd $DIR

echo Fetching 02packages ...

(
  wget -q -O 02packages http://cpan.org/modules/02packages.details.txt.gz &&
  mv 02packages 02packages.details.txt.gz
) ||
  exit

echo Fetching CPAN-testers database ...

# this talks to the CPAN-testers metabase and populates our
# cpantesters db
./refill-cpanstatsdb.pl --finishlimit=1 --quiet

# move/rewrite records into cpandeps[dev] db
./mangledb.pl

./populate-cache.pl
./build-reverse-index.pl

echo
echo
echo Unknown OSes
echo
echo select platform, origosname, count\(\*\) from cpanstats where os=\'Unknown OS\' group by platform, origosname\; |./dbish 2>/dev/null
