#!/bin/sh

cd /web/cpandeps-modperl/db

wget -q http://perl.grango.org/cpanstats.db.gz
gzip -d cpanstats.db.gz && (
  ../optimisedb.pl;
  cp cpantestresults cpantestresults.previous;
  mv cpanstats.db cpantestresults
)

rm db/cpanstats.db.gz >/dev/null 2>/dev/null
