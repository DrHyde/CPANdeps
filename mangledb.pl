#!/usr/local/bin/perl

use strict;
use warnings;
use DBI;
use Data::Dumper;

my $dbh = DBI->connect("dbi:SQLite:dbname=cpanstats.db");

print "Putting 02packages into db ...\n";
$dbh->do("CREATE TABLE packages (module PRiMARY KEY, version, file)");
my $sth = $dbh->prepare("INSERT INTO packages (module, version, file) VALUES (?, ?, ?)");
open(PACKAGES, 'gzip -dc 02packages.details.txt.gz |');
    while(<PACKAGES> ne "\n") {}; # throw away headers
    while(my $line = <PACKAGES>) {
        chomp($line);
        my($module, $version, $file) = split(/\s+/, $line, 3);
	die("Couldn't import [$module, $version, $file]\n")
	  unless($sth->execute($module, $version, $file))
    }
close(PACKAGES);

print "Deleting rubbish ...\n";
$dbh->do(q{delete from cpanstats where state='cpan' or perl='0'});

print "Creating indices ...\n";
$dbh->do("CREATE INDEX perlidx ON cpanstats (perl)");
$dbh->do("CREATE INDEX platformidx ON cpanstats (platform)");

print "Finding dev versions of perl ...\n";
$dbh->do("alter table cpanstats add column is_dev_perl"); # not yet used
$dbh->do("update cpanstats set is_dev_perl='0'");
foreach my $ver (qw(5.7 5.9 5.11 %patch)) {
    print "  $ver\n";
    $dbh->do("update cpanstats set is_dev_perl='1' where perl like '$ver%'");
}
print "Indexing ...\n";
$dbh->do("CREATE INDEX isdevperlidx ON cpanstats (is_dev_perl)");

print "Merging perl versions ...\n";
foreach my $ver (qw(
    5.3 5.4 5.5
    5.7.2 5.7.3
    5.8.0 5.8.1 5.8.2 5.8.8 5.8.9
    5.9.0 5.9.1 5.9.2 5.9.3 5.9.4 5.9.5 5.9.6
    5.10.0 5.10.1 5.10.2 5.10.3 5.10.4
    5.11.0 5.11.1 5.11.2
)) {
    print "  $ver\n";
    $dbh->do("update cpanstats set perl='$ver' where perl like '$ver%'");
}

print "Merging OSes ...\n";
$dbh->do("alter table cpanstats add column os");
$dbh->do("alter table cpanstats add column arch"); # not yet used

my %os_by_platform = (
    '%linux%'     => 'Linux',               '%freebsd%'   => 'FreeBSD',
    '%openbsd%'   => 'OpenBSD',             '%netbsd%'    => 'NetBSD',
    '%bsdos%'     => 'BSD OS',              '%darwin%'    => 'Mac OS X',
    '%MacOS%'     => 'Mac OS classic',      '%MacPPC%'    => 'Mac OS classic',
    '%aix%'       => 'AIX',                 '%osf%'       => 'OSF',
    '%sco%'       => 'SCO',                 '%pa-risc%'   => 'HP-UX',
    '%irix%'      => 'Irix',                '%solaris%'   => 'SunOS/Solaris',
    '%cygwin%'    => 'Windows (Cygwin)',    '%win32%'     => 'Windows (Win32)',
    '%s390%'      => 'OS390/zOS',           '%VMS_%'      => 'VMS',
    '%dragonfly%' => 'Dragonfly BSD',       '%os2%'       => 'OS/2',
    '%mirbsd%'    => 'MirOS BSD',
    '%i486-gnu-thread-multi%' => 'Linux', # Debian 4.2.1-6 ?
    '%i686-AT386-gnu%' => 'GNU Hurd',     # GNU debian 0.3 GNU-Mach 1.3/Hurd-0.3 i686-AT386 GNU
    'i486-gnu'     => 'GNU Hurd',
    '%ARCHREV_0%'  => 'HP-UX', # IA64.ARCHREV_0-LP64 / IA64.ARCHREV_0-thread-multi
);
foreach my $platform (keys %os_by_platform) {
    print "  $platform -> $os_by_platform{$platform}\n";
    $dbh->do("
        UPDATE cpanstats
           SET os='$os_by_platform{$platform}'
         WHERE platform LIKE '$platform' AND os IS NULL"
    );
}

print "  anything else -> Unknown OS\n";
$dbh->do("CREATE INDEX osidx ON cpanstats (os)");
$dbh->do("UPDATE cpanstats SET os='Unknown OS' WHERE os IS NULL");

print "Caching list of perls\n";
open(PERLS, ">perls") || die("Can't cache list of perl versions\n");
print PERLS Dumper([map { $_->[0] } @{$dbh->selectall_arrayref("SELECT DISTINCT perl FROM cpanstats")}]);
close(PERLS);

print "Caching list of OSes\n";
open(OSES, ">oses") || die("Can't cache list of OSes\n");
print OSES Dumper([map { $_->[0] } @{$dbh->selectall_arrayref("SELECT DISTINCT os FROM cpanstats")}]);
close(OSES);

$dbh->do("alter table cpanstats add column osfamily"); # not yet used
$dbh->do("alter table cpanstats add column perlmajorver"); # not yet used
# $dbh->do("VACUUM");