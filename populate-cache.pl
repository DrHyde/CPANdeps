#!/usr/local/bin/perl

use strict;
use warnings;
use DBI;
use Data::Dumper;
use LWP::UserAgent;

my $VERSION = 0.9;
my $ua = LWP::UserAgent->new(
    agent => "cpandeps-cache/$VERSION",
    from => 'cpandeps@cantrell.org.uk'
); 

my $dbh = DBI->connect("dbi:SQLite:dbname=db/cpantestresults");

print "Updating cache ...\n";

my @files = map { @{$_} } @{$dbh->selectall_arrayref("
    SELECT DISTINCT(file) FROM packages
")};

foreach my $file (@files) {
    $file =~ m{^./../([^/]+)(/.*)?/([^/]*).(tar.gz|tgz|zip)$};
    my($author, $dist) = ($1, $3);
    my $local_file  = "db/$dist.yml";
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
        print "$dist ...\n\t$remote_file -> \n\t$local_file\n";
	sleep 1;
    }
}

# my %packages = map { @{$_} } @{
#     $dbh->selectall_arrayref("
#         SELECT dist, max(version)
# 	  FROM cpanstats
# 	GROUP BY dist
#     ")
# };
# 
# foreach my $dist (keys %packages) {
#     my $version = $packages{$dist};
#     cache_test_results(
#         dist => $dist, version => $version,
# 	dumpfile => "db/$dist-$version-any_version-any_OS-0.dd"
#     );
#     cache_test_results(
#         dist => $dist, version => $version,
# 	perl => '5.10.0',
# 	dumpfile => "db/$dist-$version-5.10.0-any_OS-0.dd"
#     );
# }

sub cache_test_results {
    my %params = @_;
    return if(-e $params{dumpfile});

    my %states = map { @{$_} } @{
        $dbh->selectall_arrayref("
            SELECT state, count(state)
	      FROM cpanstats
	     WHERE dist = '$params{dist}' AND
	           version = '$params{version}' AND
        ".($params{perl} ? "perl = '$params{perl}' AND" : "")."
		   is_dev_perl = '0' AND
		   '1' = '1'
    	    GROUP BY dist, version, state
        ")
    };
    open(DUMPFILE, ">", $params{dumpfile}) ||
        die("Can't write $params{dumpfile}\n");
    print DUMPFILE Dumper(\%states);
    close(DUMPFILE);
    print "Wrote $params{dumpfile}\n";
}
