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

my @files = map { @{$_} } @{$dbh->selectall_arrayref("
    SELECT DISTINCT(file) FROM packages
")};

mkdir 'db';
mkdir 'db/META.yml';
mkdir 'db/MANIFEST'; # not populated by this script, as not often used
chmod 0777, qw(db db/META.yml db/MANIFEST);

foreach my $file (@files) {
    $file =~ m{^./../([^/]+)(/.*)?/([^/]*).(tar.gz|tgz|zip)$};
    my($author, $dist) = ($1, $3);
    next if(!defined($author) || !defined($dist));
    my $local_file  = "db/META.yml/$dist.yml";
    my $remote_file = "http://search.cpan.org/src/$author/$dist/META.yml";

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
