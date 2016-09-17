package CPANdepsUtils;

use strict;
use warnings;

use IPC::ConcurrencyLimit;

sub concurrency_limit {
    my $lockfile = shift;
    my $max_procs = shift || 1;
    my $type_of_request = shift || "text";

    my $limit = IPC::ConcurrencyLimit->new(
        max_procs => $max_procs,
        path      => $lockfile,
    );
    my $limitid = $limit->get_lock;
    if(not $limitid) {
        if($type_of_request eq 'text') {
            warn "Another process appears to be still running. Exiting.";
        } elsif($type_of_request eq 'html') {
            print '<meta http-equiv="refresh" content="15">Sorry, we\'re really busy right now, please wait for a bit. This page will automagically refresh soon'
        } elsif($type_of_request eq 'xml') {
            print "<?xml version='1.0'?><cpandeps><error>Sorry, too busy, try again later</error></cpandeps>";
        }
        exit(0);
    }
    return $limit;
}

1;
