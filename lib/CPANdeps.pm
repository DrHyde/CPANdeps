package CPANdeps;

use strict;

# do this before turning on warnings to avoid hatefulness
open(DEVNULL, '>>/dev/null') || die("Can't open /dev/null\n");

use warnings;

use CGI;
use DBI;
use Parse::CPAN::Packages;
use YAML ();

use Data::Dumper;
use LWP::UserAgent;
use Template;

open(DEVBUILD, 'dev_build');
$/ = undef;
my $devbuild = <DEVBUILD>;
close(DEVBUILD);

my $home = "/web/cpandeps$devbuild.cantrell.org.uk";

my $p;
{
    open(local *STDERR, '>&DEVNULL') || die("Can't squish STDERR\n");
    $p = Parse::CPAN::Packages->new('db/02packages.details.txt.gz');
}

$Template::Stash::SCALAR_OPS->{int} = sub {
    my $scalar = shift;
    return int(0 + $scalar);
};

$Data::Dumper::Sortkeys = 1;
my $tt2 = Template->new(
    INCLUDE_PATH => "$home/templates";
);

my $VERSION = '0.1mp';

sub render {
    my($q, $ttvars) = @_;
    $tt2->process('cpandeps.tt2', $ttvars, sub { $q->print(@_); }) ||
        die($tt2->error());
}

sub go {
    my $q = CGI->new();
    print "Content-type: text/html\n\n";
    my $ua = LWP::UserAgent->new(
        agent => "cpandeps/$VERSION",
        from => 'cpandeps@cantrell.org.uk'
    );
    my $ttvars = {};
    my $dbh = DBI->connect("dbi:SQLite:dbname=$home/db/cpantestresults", '', '');
    my $sth = $dbh->prepare("
          SELECT state, COUNT(state) FROM cpanstats
           WHERE dist=?
             AND version=?
             AND state IN ('fail', 'pass', 'na', 'unknown')
        GROUP BY state
    ");

    my $module = $ttvars->{module} = $q->param('module');

    # $ttvars->{perls} =[map { @{$_} } @{$dbh->selectall_arrayref("SELECT DISTINCT perl FROM cpanstats")}];
    # $ttvars->{platforms} = [map { @{$_} } @{$dbh->selectall_arrayref("SELECT DISTINCT platform FROM cpanstats")}];
    my $distschecked = {};
    if($module) {
        $ttvars->{modules} = [ checkmodule($module, -4, $distschecked, $sth, $ua) ];
    }

    render($q, $ttvars);
}

sub checkmodule {
    my($module, $indent, $distschecked, $sth, $ua) = @_;
    my $warning = '';
    $indent += 4;

    my $m = $p->package($module);
    return () unless($m);
    my $dist = $m->distribution();

    my $author = $dist->cpanid();
    my $distname = $dist->prefix();

    return () if(!defined($distname) || $distschecked->{$distname} || $module eq 'perl');
    $distschecked->{$distname} = 1;

    my $CPANfile = $distname;
    (my $version = $distname) =~ s/.*-([^-]+)\.(tar\.gz|zip)/$1/;

    return {
        name   => $module,
        distname => $distname,
        version  => $version,
        indent   => $indent,
        cpantestersurl => "http://search.cpan.org/search?query=$module",
        warning => "Couldn't find module",
    } unless(defined($dist) && defined($distname));

    $author   = '' unless(defined($author));
    $distname = '' unless(defined($distname));
    $version = '' unless(defined($version));

    $distname =~ s!(^.*/|(\.tar\.gz|\.zip)$)!!g;

    my @requires = getreqs($author, $distname, $ua);
    if($requires[0] && $requires[0] eq '!') {
        @requires = ();
        $warning = "Couldn't get dependencies";
    }

    $distname =~ s/\.pm|-[^-]*$//g;

    my $testresults = ($distname eq 'perl') ?
        'Core module' :
        gettestresults($sth, $distname, $version);

    return {
        name     => $module,
        distname => $distname,
        CPANfile => $CPANfile,
        version  => $version,
        indent   => $indent,
        cpantestersurl => "http://cpantesters.perl.org/show/$distname.html",
        warning => $warning,
        ref($testresults) ?
            %{$testresults} :
            (textresult   => $testresults)
    }, map {
        checkmodule($_, $indent, $distschecked, $sth, $ua);
    } @requires
}

sub gettestresults {
    my($sth, $distname, $version) = @_;
    $sth->execute($distname, ''.$version);
    my $r = $sth->fetchall_arrayref();
    if(ref($r)) { $r = { map { $_->[0] => $_->[1] } @{$r} }; }
     else { return 'Error getting test results'; }

    $r->{$_} = 0 for(grep { !exists($r->{$_}) } qw(fail pass unknown na));
    return $r;
}

sub getreqs {
    my($author, $distname, $ua) = @_;
    my $cachefile = "$home/db/$distname.yml";
    my $yaml;
    local $/ = undef;

    # if we have a valid (less than 7 day old) cache file, read it
    if(-e $cachefile && (stat($cachefile))[9] + 7 * 86400 > time()) {
        open(YAML, $cachefile) || die("Can't read $cachefile\n");
        $yaml = <YAML>;
        close(YAML);
    } else {
        # read from interwebnet
        my $res = $ua->request(HTTP::Request->new(
            GET => "http://search.cpan.org/src/$author/$distname/META.yml"
        ));
        if(!$res->is_success()) {
            return ('!');
        } else {
            $yaml = $res->content();
        }
        open(YAML, ">$cachefile") || die("Can't write $cachefile\n");
        print YAML $yaml;
        close(YAML);
    }
    eval { $yaml = YAML::Load($yaml); };
    return ('!') if($@ || !defined($yaml));

    $yaml->{requires} ||= {};
    $yaml->{build_requires} ||= {};
    return keys %{{ %{$yaml->{requires}}, %{$yaml->{build_requires}} }};
}

1;
