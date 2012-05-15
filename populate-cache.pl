#!/usr/local/bin/perl

use strict;
use warnings;
use DBI;
use Data::Dumper;
use LWP::UserAgent;
use FindBin;

chdir $FindBin::Bin;
my $dbname = ($FindBin::Bin =~ /dev/) ? 'cpandepsdev' : 'cpandeps';

my $VERSION = 0.9;
my $ua = LWP::UserAgent->new(
    agent => "cpandeps-cache/$VERSION",
    from => 'cpandeps@cantrell.org.uk'
); 

my $dbh = DBI->connect("dbi:mysql:database=$dbname", "root", "");

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

    foreach my $tuple (
        { local => "db/META.yml/$dist.yml", remote => "http://search.cpan.org/src/$author/$dist/META.yml" },
        { local => "db/META.yml/$dist.json", remote => "http://search.cpan.org/src/$author/$dist/META.json" },
    ) {
        my $local_file  = $tuple->{local};
        my $remote_file = $tuple->{remote};

        next if(-e $local_file);
  
        my $res = $ua->request(HTTP::Request->new(GET => $remote_file));
        if(!$res->is_success()) {
            next;
        } else {
          my $yaml = $res->content();
          open(FILE, '>', $local_file) || die("Can't write $local_file\n");
          print FILE $yaml;
          close(FILE);
          sleep 1;
        }
    }
}
