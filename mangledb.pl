#!/usr/local/bin/perl

use strict;
use warnings;
use DBI;
use Data::Dumper;
use FindBin;

my $dbname = ($FindBin::Bin =~ /dev/) ? 'cpandepsdev' : 'cpandeps';
chdir($FindBin::Bin);

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
    'bsdos' => 'BSD OS',
    'cygwin' => 'Windows (Cygwin)',
    'darwin' => 'Mac OS X',
    'Mac OS X' => 'Mac OS X',
    'dec_osf' => 'Tru64/OSF/Digital UNIX',
    'dragonfly' => 'Dragonfly BSD',
    'freebsd' => 'FreeBSD',
    'Freebsd' => 'FreeBSD',
    'FreeBSD' => 'FreeBSD',
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
    'MacOS' => 'Mac OS classic',
    'macos' => 'Mac OS classic',
    'midnightbsd' => 'Midnight BSD',
    'mirbsd' => 'MirOS BSD',
    'MSWin32' => 'Windows (Win32)',
    'mswin32' => 'Windows (Win32)',
    'netbsd' => 'NetBSD',
    'NetBSD' => 'NetBSD',
    'openbsd' => 'OpenBSD',
    'OpenBSD' => 'OpenBSD',
    'openosname=openbsd' => 'OpenBSD',
    'openThis' => 'OpenBSD',
    'os2' => 'OS/2',
    'os390' => 'OS390/zOS',
    'nto' => 'QNX Neutrino',
    'sco' => 'SCO Unix',
    'solaris' => 'Solaris',
    'VMS' => 'VMS',
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
    $record->{is_dev_perl} = ($record->{perl} =~ /(^5\.(7|9|11|13|15|17|19)|rc|patch)/i) ? 1 : 0;
    foreach my $ver (qw(
        5.3 5.4 5.5
        5.7.2 5.7.3
        5.8.0 5.8.1 5.8.2 5.8.3 5.8.4 5.8.5 5.8.6 5.8.7 5.8.8 5.8.9
        5.9.0 5.9.1 5.9.2 5.9.3 5.9.4 5.9.5 5.9.6
        5.10.0 5.10.1
        5.11.0 5.11.1 5.11.2 5.11.3 5.11.4 5.11.5 5.11.6
	5.12.0 5.12.1 5.12.2 5.12.3 5.12.4 5.12.5
	5.13.0 5.13.1 5.13.2 5.13.3 5.13.4 5.13.5 5.13.6 5.13.7 5.13.8 5.13.9
          5.13.10 5.13.11
	5.14.0 5.14.1 5.14.2 5.14.3 5.14.4
	5.15.0 5.15.1 5.15.2 5.15.3 5.15.4 5.15.5 5.15.6 5.15.7 5.15.8 5.15.9
        5.16.0 5.16.1 5.16.2 5.16.3
        5.17.0 5.17.1 5.17.2 5.17.3 5.17.4 5.17.5 5.17.6 5.17.7 5.17.8 5.17.9
          5.17.10 5.17.11
        5.18.0 5.18.1 5.18.2 5.18.3
        5.19.0 5.19.1 5.19.2 5.19.3 5.19.4 5.19.5 5.19.6 5.19.7 5.19.8 5.19.9
          5.19.10
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
	  ($record->{id} =~ /^( # Linux reports with no osname or platform
	    8360088| 8391786| 8426789| 8426792| 8666860| 8666986| 8666992|
	    8667489| 8846399| 8846457| 8846785| 8846842| 8847736| 8847756|
	    8847763| 8848211| 8850666| 8851147| 8851289| 8851322| 8851324|
	    8864608| 8864626| 8865575| 8866632| 8867205| 8868845| 8870420|
	    8876404| 8876438| 8878792| 8878811| 8878885|
	    15874513 | 15915011 | 16508362 | 16608832 | 16711231 |
	    17037247 | 17162708
	                                )$/x) ? 'Linux' :
          ($record->{id} =~ /^( # Debian FreeBSD reports
	    13808906
	                                )$/x) ? 'FreeBSD (Debian)' :
	                                        'Unknown OS';
      }
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
