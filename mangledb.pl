#!/usr/local/bin/perl

use strict;
use warnings;
use DBI;
use Data::Dumper;
use FindBin;

my $dbname = ($FindBin::Bin =~ /dev/) ? 'cpandepsdev' : 'cpandeps';
chdir($FindBin::Bin);

$| = 1;

my $mysqldbh = DBI->connect("dbi:mysql:database=$dbname", "root", "");
my $barbiedbh = DBI->connect("dbi:SQLite:dbname=barbiesdb");

print "Putting 02packages into db ...\n";
{
  my $sth = $mysqldbh->prepare("INSERT INTO packages (module, version, file) VALUES (?, ?, ?)");
  $mysqldbh->{'AutoCommit'} = 0;
  $mysqldbh->do('DELETE FROM packages');
  open(PACKAGES, 'gzip -dc 02packages.details.txt.gz |');
      while(<PACKAGES> ne "\n") {}; # throw away headers
      while(my $line = <PACKAGES>) {
          chomp($line);
          my($module, $version, $file) = split(/\s+/, $line, 3);
  	die("Couldn't import [$module, $version, $file]\n")
  	  unless($sth->execute($module, $version, $file));
      }
  close(PACKAGES);
  $mysqldbh->{'AutoCommit'} = 1;
}

print "Finding most recent result in db ...\n";
my $maxid = $mysqldbh->selectall_arrayref('SELECT MAX(id) FROM cpanstats')->[0]->[0] || 0;

my $outputstep = 1000;
print "Finding/inserting new test results.  Each dot is $outputstep records ...\n";
{
  my $insertcount = 0;
  my @os_by_osname = (
    '' => 'Unknown OS',
    'aix' => 'AIX',
    'beos' => 'BeOS',
    'bsdos' => 'BSD OS',
    'cygwin' => 'Windows (Cygwin)',
    'darwin' => 'Mac OS X',
    'dec_osf' => 'Tru64/OSF/Digital UNIX',
    'dragonfly' => 'Dragonfly BSD',
    'freebsd' => 'FreeBSD',
    'gnu' => 'GNU Hurd',
    'gnukfreebsd' => 'FreeBSD (Debian)',
    'haiku' => 'Haiku',
    'hpux' => 'HP-UX',
    'irix' => 'Irix',
    'linux' => 'Linux',
    'MacOS' => 'Mac OS classic',
    'midnightbsd' => 'Midnight BSD',
    'mirbsd' => 'MirOS BSD',
    'MSWin32' => 'Windows (Win32)',
    'netbsd' => 'NetBSD',
    'openbsd' => 'OpenBSD',
    'OpenBSD' => 'OpenBSD',
    'openosname=openbsd' => 'OpenBSD',
    'openThis' => 'Unknown OS',
    'os2' => 'OS/2',
    'os390' => 'OS390/zOS',
    'sco' => 'SCO Unix',
    'solaris' => 'Solaris',
    'VMS' => 'VMS',
  );
  my $select = $barbiedbh->prepare("
    SELECT id, state, tester, dist, version, platform, perl, platform, osname
      FROM cpanstats
     WHERE id > $maxid AND
           state != 'cpan' AND
	   perl != '0'
  ");
  my $insert = $mysqldbh->prepare('
    INSERT INTO cpanstats (id, state, tester, dist, version, perl, is_dev_perl, os, platform, origosname)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ');
  $select->execute();
  $mysqldbh->{'AutoCommit'} = 0;
  while(my $record = $select->fetchrow_hashref()) {
    $record->{is_dev_perl} = ($record->{perl} =~ /(^5\.(7|9|11)|patch)/) ? 1 : 0;
    foreach my $ver (qw(
        5.3 5.4 5.5
        5.7.2 5.7.3
        5.8.0 5.8.1 5.8.2 5.8.3 5.8.4 5.8.5 5.8.6 5.8.7 5.8.8 5.8.9
        5.9.0 5.9.1 5.9.2 5.9.3 5.9.4 5.9.5 5.9.6
        5.10.0 5.10.1 5.10.2 5.10.3 5.10.4
        5.11.0 5.11.1 5.11.2 5.11.3 5.11.4 5.11.5 5.11.6
	5.12.0 5.12.1 5.12.2
	5.13.0 5.13.1 5.13.2
    )) {
      $record->{perl} = $ver if($record->{perl} =~ /^$ver/);
    }
    $record->{os} = 'Unknown OS';
    my @temp_os_by_osname = @os_by_osname;
    while(@temp_os_by_osname) {
      my($osname, $os) = (shift(@temp_os_by_osname), shift(@temp_os_by_osname));
      if($record->{osname} eq "$osname") {
        $record->{os} = $os;
	last;
      }
      if($record->{os} eq 'Unknown OS') { # a handful of records have no osname
        $record->{os} =
	  ($record->{platform} =~ /mirbsd/i)  ? 'MirOS BSD' :
	  ($record->{platform} =~ /openbsd/i) ? 'OpenBSD' :
	                                        'Unknown OS';
      }
    }
    $insert->execute(
      map { $record->{$_} } qw(id state tester dist version perl is_dev_perl os platform osname)
    );
    if(!(++$insertcount % $outputstep)) {
      print '.';
      $mysqldbh->{'AutoCommit'} = 1;
      $mysqldbh->{'AutoCommit'} = 0;
    }
  }
  $mysqldbh->{'AutoCommit'} = 1;
  print "\n";
}

mkdir 'db';
chmod 0777, 'db';

print "Caching list of perls\n";
open(PERLS, ">db/perls") || die("Can't cache list of perl versions\n");
print PERLS Dumper([map { $_->[0] } @{$mysqldbh->selectall_arrayref("SELECT DISTINCT perl FROM cpanstats")}]);
close(PERLS);

print "Caching list of OSes\n";
open(OSES, ">db/oses") || die("Can't cache list of OSes\n");
print OSES Dumper([map { $_->[0] } @{$mysqldbh->selectall_arrayref("SELECT DISTINCT os FROM cpanstats")}]);
close(OSES);
