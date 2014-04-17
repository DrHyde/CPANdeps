#!/usr/local/bin/perl

# use 5.010;
use strict;
use warnings;

=head1 NAME



=head1 SYNOPSIS

  ~/src/installed-perls/v5.16.0/4e6d/bin/perl bin/refill-cpanstatsdb.pl

=head1 OPTIONS

=over 8

=cut

my @opt = <<'=back' =~ /B<--(\S+)>/g;

=item B<--help|h!>

This help

=item B<--finishlimit=i>

A query that yields a result with less rows than this number is the
signal to refrain from further refill queries and finish this program.
Defaults to 0 which means other limits are needed to stop this
program.

Note: before we invented the sleep parameters, this was the way how we
stopped the program. Probably not needed anymore.

=item B<--maxins=i>

No default, which means no limit. Maximum number of records to inject.
If set to zero, we test the surroundings, then exit.

=item B<--maxtime=i>

Maximum time in seconds this program should run. Defaults to 1770. If
set to zero, no limit.

=item B<--sleeplimit=i>

A query that yields a result with less rows than this number is the
signal to sleep for $Opt{sleeptime} seconds before querying again.
Defaults to 500. Do not set it too low, it would produce an annoying
amount of logfiles.

=item B<--sleeptime=i>

For how long to sleep in the case of $Opt{sleeplimit} undercut.
Defaults to 150 seconds.

=back

=head1 DESCRIPTION

Replacement for the job that downloaded the whole cpanstats.db and
gunzipped it.

Now we simply repeatedly fetch the descriptions for the next 2500
reports until the supply dries out. Thus we reach a new max, write all
the stuff to the db and let the other jobs work from there.

=head1 TODO

remove unneeded data, maybe split them out.

=head1 SEE ALSO

refill-cpanstatsdb-minutes.pl

=cut


use FindBin;
use lib "$FindBin::Bin/lib";
use CPANdeps;

use Dumpvalue;
use File::Basename ();
use File::Path ();
use File::Spec;
use File::Temp;
use Getopt::Long;
use Pod::Usage;
use Hash::Util qw(lock_keys);
use List::Util qw(min);

our %Opt;
lock_keys %Opt, map { /([^=|!]+)/ } @opt;
GetOptions(\%Opt,
           @opt,
          ) or pod2usage(1);
if ($Opt{help}) {
    pod2usage(0);
}
$Opt{finishlimit} ||= 0;
$Opt{sleeplimit} ||= 500;
$Opt{sleeptime} ||= 150;
$Opt{maxtime} = 1770 unless defined $Opt{maxtime};

my $limit = CPANdeps::concurrency_limit("/tmp/refill-testers-db/lock");

use DBI;
use Time::HiRes qw(time);
use JSON::XS ();
use List::Util qw(max);
use CPAN::Testers::WWW::Reports::Query::Reports;

our $jsonxs = JSON::XS->new->indent(0);

my($sth,$current_max_id);
{
    my $dbh = DBI->connect("dbi:mysql:dbname=cpantesters", 'root', '') or die "Could not connect to 'cpantesters': $DBI::err";
    my $sql = "select max(id) from cpanstats";
    $sth = $dbh->prepare($sql);
    {
        my $rv = eval { $sth->execute(); };
        unless ($rv) {
            my $err = $sth->errstr;
            die "Warning: error occurred while executing '$sql': $err";
        }
    }
    my(@row) = $sth->fetchrow_array();
    $current_max_id = $row[0] || 0;
    warn "INFO: In cpantesters db found max id '$current_max_id'";
    $sql = "INSERT INTO cpanstats
 (id,guid,state,dist,version,platform,perl,osname,osvers) values
 (?, ?,   ?,    ?,   ?,      ?,       ?,   ?,     ?)";
    $sth = $dbh->prepare($sql);
}
my $query = CPAN::Testers::WWW::Reports::Query::Reports->new;
my $nextid;
$nextid = $current_max_id+1;
my($inscount) = 0;
my($queries_n,$queries_time) = (0,0);
QUERY: while () {
    warn sprintf "%s: Next query starting with %s\n", scalar gmtime(), $nextid;
    my $result = $query->range("$nextid-");
    my $querycnt = keys %$result;
    my $thismax = $querycnt > 0 ? max(keys %$result) : undef;
    warn sprintf "%s: Got %d records from '%s' to '%s'\n", scalar gmtime(), $querycnt, $nextid, $thismax||"<UNDEF>";
    if (defined($Opt{maxins}) && $Opt{maxins} <= 0) {
        last QUERY;
    }
    if ( $Opt{finishlimit} && $querycnt < $Opt{finishlimit}) {
        last QUERY;
    }
    unless ($thismax){
        if ($Opt{maxtime} && time+$Opt{sleeptime}-$^T >= $Opt{maxtime}) {
            last QUERY;
        } else {
            sleep $Opt{sleeptime};
            next QUERY;
        }
    }

    # so we have some work to do
    my @gmtime = gmtime;
    my $logfile = sprintf
        (
         "%s/var/refill-cpanstatsdb/%04d/%02d/%04d%02d%02dT%02d%02d-%d-MAX.json.gz",
         $ENV{HOME},
         1900+$gmtime[5],
         1+$gmtime[4],
         1900+$gmtime[5],
         1+$gmtime[4],
         @gmtime[3,2,1],
         $nextid,
        );
    File::Path::mkpath File::Basename::dirname $logfile;
    if (-e $logfile) {
        die "ALERT: found '$logfile', will not overwrite it";
    }
    open my $fh, "|-", "gzip -9c > $logfile" or die "Could not open gzip to '$logfile': $!";
    my $next_log = time + 60;
    #   dist     => "Attribute-Overload",
    #   fulldate => 201205262229,
    #   guid     => "4454e538-a782-11e1-802a-3db30df65b4f",
    #   id       => 22285792,
    #   osname   => "linux",
    #   osvers   => "2.6.18-1.2798.fc6",
    #   perl     => "5.16.0 RC0",
    #   platform => "i686-linux-thread-multi-64int-ld",
    #   postdate => 201205,
    #   state    => "fail",
    #   tester   => "Khen1950fx\@aol.com",
    #   type     => 2,
    #   version  => "1.100710",
    my $i = 0;
    my $max_seen;
 REC: for my $id (sort {$a <=> $b} keys %$result) {
        if (defined($Opt{maxins}) && $inscount >= $Opt{maxins}) {
            last REC;
        }
        if ($Opt{maxtime} && time-$^T >= $Opt{maxtime}) {
            last REC;
        }
        $max_seen = $id;
        my $record = $result->{$id};
        if ($id > $current_max_id) {
            my $start = time;
            $sth->execute($id,@{$record}{qw(guid state dist version platform perl osname osvers)});
            $queries_n++;
            $queries_time += time - $start;
        }
        # ddx $record; # see also Data::Dump line
        print $fh $jsonxs->encode($record), "\n";
        $i++;
        if (time >= $next_log) {
            warn sprintf "%s: %d records inserted\n", scalar gmtime(), $i;
            $next_log += 60;
        }
        $inscount++;
    }
    close $fh or die "Could not close gzip to '$logfile': $!";
    my $finallogfile = $logfile;
    unless ($max_seen) {
        $max_seen = $nextid - 1;
    }
    $finallogfile =~ s/MAX/$max_seen/;
    rename $logfile, $finallogfile or die "Could not rename $logfile, $finallogfile: $!";
    if (defined($Opt{maxins}) && $inscount >= $Opt{maxins}) {
        last QUERY;
    }
    my $sleeptime = 0;
    if ( $Opt{sleeplimit} && $querycnt < $Opt{sleeplimit} ) {
        $sleeptime = $Opt{sleeptime};
    }
    if ($Opt{maxtime} && time+$sleeptime-$^T >= $Opt{maxtime}) {
        last QUERY;
    }
    if ($sleeptime) {
        sleep $sleeptime;
    }
    $nextid = $thismax+1;
}
if ($queries_n) {
    warn sprintf "STATS: avg ins time per rec %.5f\n", $queries_time/$queries_n;
}

# for the record: today I added the two:
# CREATE INDEX ixdist ON cpanstats (dist);  # took ca 30 minutes
# CREATE INDEX ixtypestate ON cpanstats (type, state);
# DROP INDEX ixvers;

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
