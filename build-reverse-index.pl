#!/usr/local/bin/perl

use strict;
use warnings;
use DBI;
use Data::Dumper;
use FindBin;
use YAML ();

$/ = undef;

chdir $FindBin::Bin;
my $dbname = ($FindBin::Bin =~ /dev/) ? 'cpandepsdev' : 'cpandeps';

my $dbh = DBI->connect("dbi:mysql:database=$dbname", "root", "");

print "Building reverse index ...\n";

my @files = map { @{$_} } @{$dbh->selectall_arrayref("
    SELECT DISTINCT(file) FROM packages
")};

my $mods_in_file = $dbh->prepare('SELECT module from packages where file=?');

mkdir 'db';
mkdir 'db/reverse';
chmod 0777, qw(db db/reverse);

my %METAyml;
opendir(DIR, 'db/META.yml') || die("can't open db/META.yml\n");
foreach(grep { -f "db/META.yml/$_" } readdir(DIR)) {
  open FILE, "db/META.yml/$_" || die("Can't read db/META.yml/$_\n");
  eval {
    $METAyml{$_} = YAML::Load(<FILE>);
    $METAyml{$_} = join("\n",
      keys %{$METAyml{$_}->{requires}},
      keys %{$METAyml{$_}->{build_requires}},
      keys %{$METAyml{$_}->{configure_requires}},
    );
  };
  delete $METAyml{$_} if($@);
  close(FILE);
}
closedir(DIR);

foreach my $file (@files) {
    $file =~ m{^./../([^/]+)(/.*)?/([^/]*).(tar.gz|tgz|zip)$};
    my($author, $dist) = ($1, $3);
    next if(!defined($author) || !defined($dist));
    my $local_file  = "db/reverse/$dist.yml";

    $mods_in_file->execute($file);
    my $modules = join('|', map { $_->[0] } @{$mods_in_file->fetchall_arrayref()});
    open(FILE, ">db/reverse/$dist.dd") || die("Can't write db/reverse/$dist.dd\n");
    print FILE Dumper([map { s/\.yml$//; $_ } grep { $METAyml{$_} =~ /\b($modules)\b/ } keys %METAyml]);
    close(FILE);
}
