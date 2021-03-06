#!/usr/local/bin/perl

use strict;
use warnings;
use DBI;
use Data::Dumper;
use LWP::UserAgent;
use FindBin;

$| = 1;

chdir $FindBin::Bin;
my $dbname = ($FindBin::Bin =~ /dev/) ? 'cpandepsdev' : 'cpandeps';

use lib "$FindBin::Bin/lib";
use CPANdepsUtils;
my $limit = CPANdepsUtils::concurrency_limit("/tmp/$dbname/populate-cache/lock");

my $VERSION = 1.0;
my $ua = LWP::UserAgent->new(
    agent => "cpandeps-cache/$VERSION",
    from => 'david@cantrell.org.uk'
); 

my $dbh = DBI->connect("dbi:mysql:database=$dbname", "root", "");

if(!defined($dbh)) {
    die("Failed to connect to database: $DBI::errstr\n");
}

print "Updating cache ...\n";

mkdir 'db';
mkdir 'db/META.yml';
mkdir 'db/MANIFEST'; # not populated by this script, as not often used
chmod 0777, qw(db db/META.yml db/MANIFEST);

print "Caching list of perls\n";
open(PERLS, ">db/perls") || die("Can't cache list of perl versions\n");
print PERLS Dumper([map { $_->[0] } @{$dbh->selectall_arrayref("SELECT DISTINCT perl FROM cpanstats")}]);
close(PERLS);

print "Caching list of OSes\n";
open(OSES, ">db/oses") || die("Can't cache list of OSes\n");
print OSES Dumper([map { $_->[0] } @{$dbh->selectall_arrayref("SELECT DISTINCT os FROM cpanstats")}]);
close(OSES);

my @files = map { @{$_} } @{$dbh->selectall_arrayref("
    SELECT DISTINCT(file) FROM packages
")};

print "Getting META.ymls and META.jsons\n";
foreach my $file (@files) {
    $file =~ m{^./../([^/]+)(/.*)?/([^/]*).(tar.gz|tgz|zip)$};
    my($author, $dist) = ($1, $3);
    next if(!defined($author) || !defined($dist));

    next if(
        -e "db/META.yml/$dist.yml" || -e "db/META.yml/$dist.json" ||
        (-e "db/META.yml/$dist.yml.404" && -e "db/META.yml/$dist.json.404")
    );
    foreach my $tuple (
        { local => "db/META.yml/$dist.yml", remote => "http://fastapi.metacpan.org/source/$author/$dist/META.yml" },
        { local => "db/META.yml/$dist.json", remote => "http://fastapi.metacpan.org/source/$author/$dist/META.json" },
    ) {
        my $local_file  = $tuple->{local};
        my $remote_file = $tuple->{remote};
  
        print '.';

        my $res = $ua->request(HTTP::Request->new(GET => $remote_file));
        if(!$res->is_success()) {
            open(FILE, '>', "$local_file.404") || die("Can't write $local_file.404\n");
            close(FILE);
        } else {
          my $yaml = $res->content();
          open(FILE, '>', $local_file) || die("Can't write $local_file\n");
          print FILE $yaml;
          close(FILE);
        }
    }
}
print "\n";
