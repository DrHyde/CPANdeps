#!/usr/local/bin/perl

use strict;
use warnings;
use DBI;
use Data::Dumper;
use FindBin;

chdir($FindBin::Bin);
my $dbname = ($FindBin::Bin =~ /dev/) ? 'cpandepsdev' : 'cpandeps';

use lib "$FindBin::Bin/lib";
use CPANdepsUtils;
my $limit = CPANdepsUtils::concurrency_limit("/tmp/$dbname/refill-deps-db/lock");

$| = 1;

my $cpandepsdbh    = DBI->connect("dbi:mysql:database=$dbname", "root", "");
my $cpantestersdbh = DBI->connect("dbi:mysql:database=cpantesters", "root", "");

print "Putting 02packages into db ...\n";
{
  my $sth = $cpandepsdbh->prepare("INSERT INTO packages (module, version, file) VALUES (?, ?, ?)");
  $cpandepsdbh->{'AutoCommit'} = 0;
  $cpandepsdbh->do('DELETE FROM packages');
  open(PACKAGES, 'gzip -dc 02packages.details.txt.gz |');
      while(<PACKAGES> ne "\n") {}; # throw away headers
      while(my $line = <PACKAGES>) {
          chomp($line);
          my($module, $version, $file) = split(/\s+/, $line, 3);
  	die("Couldn't import [$module, $version, $file]\n")
  	  unless($sth->execute($module, $version, $file));
      }
  close(PACKAGES);
  unlink('02packages.details.txt.gz');
  $cpandepsdbh->{'AutoCommit'} = 1;
}

my $outputstep = 10000;
print "Finding/inserting new test results.  Each dot is $outputstep records ...\n";
{
  my @os_by_osname = (
    '' => 'Unknown OS',
    'aix' => 'AIX',
    'beos' => 'BeOS',
    'bitrig' => 'Bitrig BSD',
    'bsdos' => 'BSD OS',
    'cygwin' => 'Windows (Cygwin)',
    'darwin' => 'Mac OS X',
    'Mac OS X' => 'Mac OS X',
    'dec_osf' => 'Tru64/OSF/Digital UNIX',
    'dragonfly' => 'Dragonfly BSD',
    'freebsd' => 'FreeBSD',
    'gnu' => 'GNU Hurd',
    'gnukfreebsd' => 'FreeBSD (Debian)',
    'haiku' => 'Haiku',
    'hpux' => 'HP-UX',
    'interix' => 'Interix (MS services for Unix)',
    'irix' => 'Irix',
    'linux' => 'Linux',
    'GNU/Linux' => 'Linux',
    'linThis'   => 'Linux',
    'linuxThis' => 'Linux',
    'lThis'     => 'Linux',
    'linuThis'  => 'Linux', 
    'macos' => 'Mac OS classic',
    'midnightbsd' => 'Midnight BSD',
    'minix'       => 'Minix',
    'mirbsd' => 'MirOS BSD',
    'mswin32' => 'Windows (Win32)',
    'netbsd' => 'NetBSD',
    'openbsd' => 'OpenBSD',
    'openosname=openbsd' => 'OpenBSD',
    'openThis' => 'OpenBSD',
    'os2' => 'OS/2',
    'os390' => 'OS390/zOS',
    'nto' => 'QNX Neutrino',
    'sco' => 'SCO Unix',
    'solaris' => 'Solaris',
    'vms' => 'VMS',
  );
  my $insert = $cpandepsdbh->prepare('
    INSERT INTO cpanstats (id, state, dist, version, perl, is_dev_perl, os, platform, origosname)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  ');

  # can't deal with eleventy zillion records at once, so eat them this many at a time
  my $records_to_fetch = 1000000;

SELECTLOOP:
  my $insertcount = 0;
  my $maxid = $cpandepsdbh->selectall_arrayref('SELECT MAX(id) FROM cpanstats')->[0]->[0] || 0;
  my $select = $cpantestersdbh->prepare("
    SELECT id, state, dist, version, platform, perl, platform, osname
      FROM cpanstats
     WHERE id > $maxid AND
           id < $maxid + $records_to_fetch AND
           state IN ('pass', 'fail', 'na', 'unknown') AND
	   perl != '0'
  ");
  $select->execute();
  $cpandepsdbh->{'AutoCommit'} = 0;
  while(my $record = $select->fetchrow_hashref()) {
    # NB the order of these two lines is important!
    $record->{is_dev_perl} = ($record->{perl} =~ /(^v?5\.(7|9|[1-9][13579]))|rc|patch/i) ? 1 : 0;
    $record->{perl} =~ s/\s+(RC|patch).*//i;
    $record->{perl} =~ s/^v//;
    $record->{os} = 'Unknown OS';
    my @temp_os_by_osname = @os_by_osname;
    while(@temp_os_by_osname) {
      my($osname, $os) = (shift(@temp_os_by_osname), shift(@temp_os_by_osname));
      if($record->{osname} && $record->{osname} =~ /^$osname$/i) {
        $record->{os} = $os;
        last;
      }
    }
    if($record->{os} eq 'Unknown OS') { # if we couldn't map it try looking at 'platform'
        $record->{platform} =~ /linux/ ? $record->{os} = 'Linux'
      : warn(sprintf(
          "Couldn't map osname '%s', platform '%s'\n",
          $record->{osname}, $record->{platform}
      ))
    }

    $insert->execute(
      map { $record->{$_} } qw(id state dist version perl is_dev_perl os platform osname)
    );
    if(!(++$insertcount % $outputstep)) {
      print '.';
      $cpandepsdbh->{'AutoCommit'} = 1;
      $cpandepsdbh->{'AutoCommit'} = 0;
    }
  }
  $cpandepsdbh->{'AutoCommit'} = 1;

  # times 0.9 because there are occasional gaps in the series, especially
  # early on
  goto SELECTLOOP if($insertcount > $records_to_fetch * 0.9);

  print "\n";
}

mkdir 'db';
chmod 0777, 'db';
