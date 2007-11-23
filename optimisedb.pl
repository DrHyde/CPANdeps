#!/usr/local/bin/perl

use strict;
use warnings;
use DBI;

my $dbh = DBI->connect("dbi:SQLite:dbname=cpanstats.db");

$dbh->do(q{delete from cpanstats where state='cpan'});

$dbh->do("CREATE INDEX perlidx ON cpanstats (perl)");
$dbh->do("CREATE INDEX platformidx ON cpanstats (platform)");

exit();

__END__

foreach my $ver (qw(
    5.7.2 5.7.3
    5.8.0 5.8.1 5.8.2 5.8.8
    5.9.0 5.9.1 5.9.2 5.9.3 5.9.4 5.9.5
    5.10
)) {
    $dbh->do("update cpanstats set perl='$ver' where perl like '$ver%'");
}

$dbh->do("alter table cpanstats add column os");
$dbh->do("alter table cpanstats add column arch");

$dbh->do("UPDATE cpanstats SET os='Linux' WHERE platform LIKE '%linux%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='FreeBSD' WHERE platform LIKE '%freebsd%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='OpenBSD' WHERE platform LIKE '%openbsd%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='NetBSD' WHERE platform LIKE '%netbsd%'   AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='BSD OS' WHERE platform LIKE '%bsdos%'    AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='Mac OS X' WHERE platform LIKE '%darwin%'    AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='Mac OS Classic' WHERE platform LIKE       '%MacOS%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='Mac OS Classic' WHERE platform LIKE       '%MacPPC%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='Win32 (Cygwin)' WHERE platform LIKE       '%cygwin%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='Win32' WHERE platform LIKE '%win32%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='AIX' WHERE platform LIKE '%aix%' AND os  IS NULL");
$dbh->do("UPDATE cpanstats SET os='OSF' WHERE platform LIKE '%osf%' AND os  IS NULL");
$dbh->do("UPDATE cpanstats SET os='SCO' WHERE platform LIKE '%sco%' AND os  IS NULL");
$dbh->do("UPDATE cpanstats SET os='HPUX' WHERE platform LIKE '%pa-risc%' AND os  IS NULL");
$dbh->do("UPDATE cpanstats SET os='Irix' WHERE platform LIKE '%irix%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='SunOS/Solaris' WHERE platform LIKE '%solaris%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='' WHERE platform LIKE '%s390%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='' WHERE platform LIKE 'ia64.archrev%' AND os IS NULL");
$dbh->do("UPDATE cpanstats SET os='' WHERE platform IN('on',                    'i686-AT386-gnu', 'i486-gnu-thread-multi') AND os IS NULL");

$dbh->do("CREATE INDEX osarchidx ON cpanstats (os, arch)");

$dbh->do("VACUUM");
