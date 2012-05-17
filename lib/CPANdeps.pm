package CPANdeps;

use strict;
use warnings;
use vars qw($VERSION);

use Cwd;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use YAML ();
use JSON ();
use DBI;
use LWP::UserAgent;

use Data::Dumper;
use Template;

use constant ANYVERSION => 'any version';
use constant ANYOS      => 'any OS';
use constant LATESTPERL  => '5.14.2';
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
    my($q, $tt2file, $ttvars) = @_;

    # at the last moment, add has_children: only needed by renderer
    for(my $i = 0; $i < $#{$ttvars->{modules}}; $i++) {
      $ttvars->{modules}->[$i]->{has_children} = 
        ($ttvars->{modules}->[$i]->{indent} < $ttvars->{modules}->[$i + 1]->{indent}) ? 1 : 0;
    }

    $ttvars->{debug} = "<h2>Debug info</h2><pre>".Dumper($ttvars)."</pre>"
        if($debug);
    
    $tt2->process(
        $q->param('xml') ? "$tt2file-xml.tt2" : "$tt2file.tt2",
        $ttvars,
        sub { $q->print(@_); }
    ) || die($tt2->error());
}

sub depended_on_by {
  my $q = CGI->new();
  print "Content-type: text/html\n\n";

  check_params($q);

  my $dist = $q->param('dist');
  if(!$dist) {
    my $module = $q->param('module');

    if (!$module)
    {
      print <<'EOF';
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE
    html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
    "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-US">
<head>
<title>The CPAN Reverse Dependency Lister</title>
<link rel="stylesheet" type="text/css" href="static/style.css" />
</head>
<body>
<h1>The CPAN Reverse Dependency Lister</h1>

<p>
Enter a module or a distribution in the GET parameters and we will return the 
CPAN distributions that depend on them. You can also fill on of these forms:
</p>

<h2>Find by Distribution</h2>

<form method="get" action="">

<p>
<b>Distribution:</b> <input name="dist" />
</p>

<p>
<input type="submit" value="Search" />
</p>

</form>

<h2>Find by Module</h2>

<form method="get" action="">

<p>
<b>Module:</b> <input name="module" />
</p>

<p>
<input type="submit" value="Search" />
</p>

</form>

</body>
</html>
EOF
      return ();
    }

    $dbh = DBI->connect("dbi:mysql:database=$dbname", "root", "");
    # TODO : Shouldn't we prepare this statement, keep it persistent and
    # execute it on each module separately?
    my $results = $dbh->selectall_arrayref(
        'SELECT file FROM packages WHERE module=?', {}, $module
    );
    return () unless @{$results};
    $dist = $results->[0]->[0];
    return () unless $dist;
    $dist =~ s!(^.*/|(\.t(ar\.)?gz|\.zip)$)!!g;
  }
  my $datafile = "$home/db/reverse/$dist.dd";
  if(!-e $datafile) {
    opendir(DIR, "$home/db/reverse") || die("Can't open dir $home/db/reverse: $!");
    $datafile = (
      grep { -f $_ && m/\/$dist-v?\d[\d.]*\.dd$/ } map { "$home/db/reverse/$_" } readdir(DIR)
    )[0];
    closedir(DIR);
  }
  my $ttvars = {
    dist => $dist,
    depended_on_by => [ @{ $datafile ? do $datafile : [] } ],
    datafile => $datafile,
  };
  render($q, 'depended-on-by', $ttvars);
}

sub check_params {
  my $q = shift;

  my $checks = {
    module => qr/^[\w:]+$/,
    dist   => qr/^[\w\.-]+$/,
    pureperl => qr/^on|([01])?$/,
    devperls => qr/^[01]?$/,
    # FIXME
    # perl => not tested here, search for "bad perl version" in sub go {}
    # os   => not tested here, search for "bad OS"
  };

  foreach my $param (keys %{$checks}) {
    die("Illegal parameter '$param', should match ".$checks->{$param}."\n")
      if($q->param($param) && $q->param($param) !~ $checks->{$param});
  }
}

sub go {
    my $q = CGI->new();
    print "Content-type: text/".($q->param('xml') ? 'xml' : 'html')."\n\n";

    check_params($q);

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

    render($q, 'cpandeps', $ttvars);
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
    (my $distversion = $distname) =~ s{^.*-(v?[\d_\.]+)\.(t(ar\.)?gz|zip)$}{$1};

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

    $distname =~ s!(^.*/|(\.t(ar\.)?gz|\.zip)$)!!g;

    my $origdistname = $distname;
    $distname =~ s/-[^-]*$//g;
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
	    devperls    => $devperls ? 1 : 0,
	);

    my %requires = ();
    my $ispureperl = '?';
    my $parsed_meta; 
    if($testresults ne 'Core module') {
        $parsed_meta = read_meta($author, $origdistname, $ua);
        %requires = getreqs($parsed_meta);
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
            parsed_meta => $parsed_meta,
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
        parsed_meta => $parsed_meta,
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
	    devperls => $devperls ? 1 : 0,
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
            my $parsed_meta = read_meta (@_);
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
	            (grep { /^Inline/ } keys %{{getreqs($parsed_meta)}})
		) ? 'N' : 'Y';
            open(MANIFEST, ">$cachefile") || die("Can't write $cachefile\n");
            print MANIFEST $ispureperl;
            close(MANIFEST);
	    return $ispureperl;
        }
    }
}

sub read_meta {
    my($author, $distname, $ua) = @_;
    my $METAymlfile  = "$home/db/META.yml/$distname.yml";
    my $METAjsonfile = "$home/db/META.yml/$distname.json";
    my $METAymlURL   = "http://search.cpan.org/src/$author/$distname/META.yml";
    my $METAjsonURL  = "http://search.cpan.org/src/$author/$distname/META.json";
    my $meta;
    local $/ = undef;

    my $parsed_meta;
    if(-e $METAymlfile) {
        warn("Cached YAML\n");
        open(YAML, $METAymlfile) || die("Can't read $METAymlfile\n");
        $meta = <YAML>;
        close(YAML);
        $parsed_meta = eval { YAML::Load($meta); };
    } elsif(-e $METAjsonfile) {
        warn("Cached JSON\n");
        open(JSON, $METAjsonfile) || die("Can't read $METAjsonfile\n");
        $meta = <JSON>;
        close(JSON);
        $parsed_meta = eval { JSON::decode_json($meta); };
    } elsif((my $res = $ua->request(HTTP::Request->new(GET => $METAymlURL)))->is_success()) {
        warn("Fetching YAML\n");
        $meta = $res->content();
        open(META, ">$METAymlfile") || die("Can't write $METAymlfile\n");
        print META $meta;
        close(META);
        $parsed_meta = eval { YAML::Load($meta); };
    } elsif((my $res = $ua->request(HTTP::Request->new(GET => $METAjsonURL)))->is_success()) {
        warn("Fetching JSON\n");
        $meta = $res->content();
        open(META, ">$METAjsonfile") || die("Can't write $METAjsonfile\n");
        print META $meta;
        close(META);
        $parsed_meta = eval { JSON::decode_json($meta); };
    } else {
        warn("nothing!?!?\n");
    }
    return $parsed_meta;
}

sub getreqs {
    my ($parsed_meta) = @_;
    return ('!', '!') if($@ || !defined($parsed_meta));

    # These are for META.yml
    $parsed_meta->{requires} ||= {};
    $parsed_meta->{build_requires} ||= {};
    $parsed_meta->{configure_requires} ||= {};
    $parsed_meta->{test_requires} ||= {};
    # These are for META.json
    $parsed_meta->{prereqs}->{runtime}->{requires} ||= {};
    $parsed_meta->{prereqs}->{configure}->{requires} ||= {};
    $parsed_meta->{prereqs}->{build}->{requires} ||= {};
    $parsed_meta->{prereqs}->{test}->{requires} ||= {};
    return 
        %{$parsed_meta->{requires}},
        %{$parsed_meta->{build_requires}},
        %{$parsed_meta->{configure_requires}},
        %{$parsed_meta->{test_requires}},
        %{$parsed_meta->{prereqs}->{runtime}->{requires}},
        %{$parsed_meta->{prereqs}->{configure}->{requires}},
        %{$parsed_meta->{prereqs}->{build}->{requires}},
        %{$parsed_meta->{prereqs}->{test}->{requires}};
}

1;
