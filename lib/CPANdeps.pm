# $Id: CPANdeps.pm,v 1.37 2009/02/14 23:03:53 drhyde Exp $

package CPANdeps;

use strict;
use warnings;
use vars qw($VERSION);

use Cwd;
use CGI;
use YAML ();

use Data::Dumper;
use Template;

use constant ANYVERSION => 'any version';
use constant ANYOS      => 'any OS';
use constant LATESTPERL  => '5.10.1';
use constant DEFAULTCORE => '5.005';
use constant MAXINT => ~0;

my $home = cwd();
my $dbname = ($home =~ /-dev/) ? 'cpandepsdev' : 'cpandeps';
my $debug = ($home =~ /-dev/) ? 1 : 0;

my $dbh;

$Template::Stash::SCALAR_OPS->{int} = sub {
    my $scalar = shift;
    return int(0 + $scalar);
};
$Template::Stash::SCALAR_OPS->{sprintf} = sub {
    my $scalar = shift;
    return sprintf(shift, $scalar);
};

$Data::Dumper::Sortkeys = 1;
my $tt2 = Template->new(
    INCLUDE_PATH => "$home/templates",
);

($VERSION = '$Id: CPANdeps.pm,v 1.37 2009/02/14 23:03:53 drhyde Exp $')
    =~ s/.*,v (.*?) .*/$1/;

sub render {
    my($q, $ttvars) = @_;


    $ttvars->{debug} = "<h2>Debug info</h2><pre>".Dumper($ttvars)."</pre>"
        if($debug);

    $tt2->process(
        $q->param('xml') ? 'cpandeps-xml.tt2' : 'cpandeps.tt2',
        $ttvars,
        sub { $q->print(@_); }
    ) || die($tt2->error());
}

sub go {
    my $q = CGI->new();
    print "Content-type: text/".($q->param('xml') ? 'xml' : 'html')."\n\n";
    my $ttvars = {
        perl => (
	    ($q->param('perl') eq 'latest') ? LATESTPERL :
	    $q->param('perl')               ? $q->param('perl') :
		                              ANYVERSION
        ),
        pureperl => ($q->param('pureperl') || 0),
        devperls => ($q->param('devperls') ? 1 : 0),
        os       => ($q->param('os') || ANYOS),
        # ugh, sorting versions is Hard.  Can't use version.pm here
        perls    => [ ANYVERSION, 
            sort {
                my($A, $B) = map {
                    my @v = split('\.', $_);
                    $v[2] = defined($v[2]) ? $v[2] : 0;
                    $v[2] + 1000 * $v[1] + 1000000 * $v[0];
                } ($a, $b);
                $A <=> $B;
            }
            (qw(5.6 5.8 5.10), @{ do "$home/db/perls" })
        ],
        oses => [ANYOS, sort { $a cmp $b } @{ do "$home/db/oses" }]
    };
    # die(Dumper($ttvars));
    my $permitted_chars = join('', @{$ttvars->{perls}});
    die("Naughty naughty - bad perl version ".$ttvars->{perl}."\n")
        if($ttvars->{perl} =~ /[^$permitted_chars]/);
        
    $permitted_chars = join('', @{$ttvars->{oses}});
    # in case list contains [, ] or -
    $permitted_chars =~ s/([\[\]\-])/\\$1/g;
    die("Naughty naughty - bad OS ".$ttvars->{os}."\n")
        if($ttvars->{os} =~ /[^$permitted_chars]/);

    my $module = $ttvars->{module} = $q->param('module');

    my $distschecked = {};
    if($module) {
        # load these as late as possible
        eval 'use DBI; use LWP::UserAgent;';
        die($@) if($@);

        $dbh = DBI->connect("dbi:mysql:database=$dbname", "root", "");
        my $ua = LWP::UserAgent->new(
            agent => "cpandeps/$VERSION",
            from => 'cpandeps@cantrell.org.uk'
        );

        $ttvars->{query} = join(' AND ', grep { $_ } (
            q{
                SELECT state, COUNT(state) FROM cpanstats
                 WHERE dist=?
                   AND version=?
                   AND state IN ('fail', 'pass', 'na', 'unknown')
            }, 
            (($ttvars->{os} eq ANYOS) ? '' : "os = '".$ttvars->{os}."'"),
            (($ttvars->{perl} eq ANYVERSION)
                ? '' : "perl LIKE '".$ttvars->{perl}."%'"),
	    (($ttvars->{devperls}) ? '' : "is_dev_perl = '0'"),
        )).
        ' GROUP BY state ';
    
        my $sth = $dbh->prepare($ttvars->{query});

        $ttvars->{modules} = [checkmodule(
            module => $module,
            moduleversion => MAXINT,
            indent => -1,
            distschecked => $distschecked,
            perl => $ttvars->{perl},
            sth => $sth,
            ua => $ua,
            q => $q,
	    pureperl => $ttvars->{pureperl},
	    devperls => $ttvars->{devperls} || 0
        )];
    }

    render($q, $ttvars);
}

sub checkmodule {
    my %params = @_;
    my($module, $moduleversion, $perl, $indent, $distschecked, $sth, $ua, $q, $pureperl, $devperls, $required_by) =
        @params{qw(
            module moduleversion perl indent distschecked sth ua q pureperl
	    devperls required_by
        )};
    my $warning = '';
    $indent += 1;

    my $results = $dbh->selectall_arrayref("
        SELECT file FROM packages WHERE module=\"$module\"
    ");
    return () unless @{$results};
    my $distname = $results->[0]->[0];
    return () unless $distname;
    (my $author = $distname) =~ s{^./../([^/]+)/.*}{$1};
    (my $distversion = $distname) =~ s{^.*/.*?([\d_\.]*)\..*?$}{$1};

    my $CPANfile     = $distname;
    my $incore       = in_core(module => $module, perl => $perl);

    return () if(
        !defined($distname) ||
        $distschecked->{$distname} ||
        $module eq 'perl'
    );

    $distschecked->{$distname} = $distversion;

    $author   = '' unless(defined($author));
    $distname = '' unless(defined($distname));
    $distversion = '' unless(defined($distversion));

    $distname =~ s!(^.*/|(\.tar\.gz|\.zip)$)!!g;

    my $origdistname = $distname;
    $distname =~ s/\.pm|-[^-]*$//g;
    my $testresults = (
        $distname eq 'perl' ||
        (defined($incore) && $incore >= $moduleversion)
    ) ?
        'Core module' :
        gettestresults(
	    sth         => $sth,
	    distname    => $distname,
	    distversion => $distversion,
	    perl        => $q->param('perl'),
	    os          => $q->param('os'),
	    devperls    => $devperls
	);

    my %requires = ();
    my $ispureperl = '?';
    if($testresults ne 'Core module') {
        %requires = getreqs($author, $origdistname, $ua);
        $ispureperl = getpurity($author, $origdistname, $ua) if($pureperl);
        if(defined($requires{'!'}) && $requires{'!'} eq '!') {
            %requires = ();
            $warning = "Couldn't get dependencies";
        }
    }

    if($params{module} eq 'Acme::Mom::Yours') {
        return {
            name     => $module,
    	    author   => $author,
            distname => $distname,
            CPANfile => $CPANfile,
            version  => $distversion,
            indent   => $indent,
            ispureperl => 1,
            warning => "Acme::Mom::Yours is silly.  Stoppit."
        };
    }

    return {
        name     => $module,
	author   => $author,
        distname => $distname,
        CPANfile => $CPANfile,
        version  => $distversion,
        indent   => $indent,
        ispureperl => $ispureperl,
        warning => $warning,
	$required_by ? (required_by => $required_by) : (),
        ref($testresults) ?
            %{$testresults} :
            (textresult   => $testresults)
    }, map {
        checkmodule(
            module => $_,
            moduleversion => $requires{$_},
	    required_by => [grep { $_ } (@{$required_by}, $module)],
            indent => $indent,
            distschecked => $distschecked,
            perl => $perl,
            sth => $sth,
            ua => $ua,
            q => $q,
	    pureperl => $pureperl,
	    devperls => $devperls
        )
    } keys %requires
}

sub in_core {
    my %params = @_;
    my($module, $perl) = @params{qw(module perl)};

    my @v = split('\.', ($perl eq ANYVERSION) ? DEFAULTCORE : $perl);
    $v[2] = 0 unless(defined($v[2]));
    my $v = sprintf("%d.%03d%03d", @v);

    if(!$Module::CoreList::VERSION) {
        eval 'use Module::CoreList';
        die($@) if($@);
    }
    my $incore = $Module::CoreList::version{0+$v}{$module};
    # warn("M:$module I:$incore P:$perl V:$v\n");
    # M:CGI::Application I: P:any version V:5.005000
    return $incore;
}

sub gettestresults {
    my %params = @_;
    my($sth, $distname, $distversion, $perl, $os, $devperls) =
        map { $params{$_} } qw(sth distname distversion perl os devperls);

    # if we have a suitably recent cache file (< 3 days), read it
    $perl ||= ANYVERSION;
    $os   ||= ANYOS;
    (my $os_without_slashes = $os) =~ s/\///g;
    my @segments = split('/', "results/dist:$distname/distver:$distversion/perl:$perl/os:$os_without_slashes/devperls:$devperls");
    my $dir = "$home/db";
    while(@segments) {
      $dir .= "/".shift(@segments);
      mkdir $dir;
      chmod 0777, $dir;
    }
    my $cachefile = "$dir/dumper.dd";

    if(-e $cachefile && (stat($cachefile))[9] + 2 * 86400 > time()) {
        return do($cachefile)
    } else {
        $sth->execute($distname, ''.$distversion);
        my $r = $sth->fetchall_arrayref();
        if(ref($r)) { $r = { map { $_->[0] => $_->[1] } @{$r} }; }
         else { return 'Error getting test results'; }
        $r->{$_} = 0 for(grep { !exists($r->{$_}) } qw(fail pass unknown na));
        eval "use Data::Dumper";
        open(DUMPER, ">$cachefile") || die("Can't write $cachefile: $!");
        print DUMPER Dumper($r);
        close(DUMPER);
        return $r;
    }
}

sub getpurity {
    my($author, $distname, $ua) = @_;
    my $cachefile = "$home/db/MANIFEST/$distname.MANIFEST";
    my $MANIFESTurl = "http://search.cpan.org/src/$author/$distname/MANIFEST";
    local $/ = undef;

    # if we have a cache file, read it
    if(-e $cachefile) {
        open(MANIFEST, $cachefile) || die("Can't read $cachefile\n");
        my $manifest = <MANIFEST>;
        close(MANIFEST);
	return $manifest;
    } else {
        # read from interwebnet
        my $res = $ua->request(HTTP::Request->new(GET => $MANIFESTurl));
        if(!$res->is_success()) {
	    open(MANIFEST, ">$cachefile") || die("Can't write $cachefile\n");
	    print MANIFEST '?';
	    close(MANIFEST);
	    return '?';
        } else {
            my @manifest = split(/[\r\n]+/, $res->content());
	    my $ispureperl =
	        (
		    (
                        (grep {
			    /\.(              # .swg and .i suggested by
			        swg        |  # Jonathan Leto
				xs         |
				[chi]
		            )(\x20|$)/ix # comments, eg in HTML::Parser
			                 # NB \x20 instead of space cos of /x
			} @manifest) &&
                        !(grep { /PurePerl/i } @manifest)
		    ) ||
	            (grep { /^Inline/ } keys %{{getreqs(@_)}})
		) ? 'N' : 'Y';
            open(MANIFEST, ">$cachefile") || die("Can't write $cachefile\n");
            print MANIFEST $ispureperl;
            close(MANIFEST);
	    return $ispureperl;
        }
    }
}

sub getreqs {
    my($author, $distname, $ua) = @_;
    my $cachefile = "$home/db/META.yml/$distname.yml";
    my $METAymlURL = "http://search.cpan.org/src/$author/$distname/META.yml";
    my $yaml;
    local $/ = undef;

    # if we have a cache file, read it
    if(-e $cachefile) {
        open(YAML, $cachefile) || die("Can't read $cachefile\n");
        $yaml = <YAML>;
        close(YAML);
    } else {
        # read from interwebnet
        my $res = $ua->request(HTTP::Request->new(GET => $METAymlURL));
        if(!$res->is_success()) {
            return ('!', '!');
        } else {
            $yaml = $res->content();
        }
        open(YAML, ">$cachefile") || die("Can't write $cachefile\n");
        print YAML $yaml;
        close(YAML);
    }
    eval { $yaml = YAML::Load($yaml); };
    return ('!', '!') if($@ || !defined($yaml));

    $yaml->{requires} ||= {};
    $yaml->{build_requires} ||= {};
    return %{$yaml->{requires}}, %{$yaml->{build_requires}};
}

1;
