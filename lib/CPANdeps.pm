package CPANdeps;

use strict;
use warnings;
use vars qw($VERSION);

$VERSION = '2.0';

use CPANdepsUtils;

use Cwd;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Digest::MD5 qw(md5_hex);
use YAML ();
use JSON ();
use DBI;
use LWP::UserAgent;

use Data::Dumper;
use Template;

use constant ANYVERSION => 'any version';
use constant ANYOS      => 'any OS';
use constant LATESTPERL  => '5.26.1';
use constant DEFAULTCORE => '5.005';
use constant MAXINT => ~0;

my $q = CGI->new();

my $home = cwd();
my $dbname = ($home =~ /-dev/) ? 'cpandepsdev' : 'cpandeps';
my $debug = ($home =~ /-dev/) ? 1 : 0;

my $dbh;
my $ttvars;

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
    PRE_CHOMP    => 1,
    POST_CHOMP   => 1,
    RECURSION    => 1,
);

sub render {
    my($q, $tt2file, $ttvars) = @_;

    # at the last moment, add has_children: only needed by renderer
    for(my $i = 0; $i < $#{$ttvars->{modules}}; $i++) {
      $ttvars->{modules}->[$i]->{has_children} = 
        ($ttvars->{modules}->[$i]->{indent} < $ttvars->{modules}->[$i + 1]->{indent}) ? 1 : 0;
    }

    $ttvars->{debug} = "<h2>Debug info</h2><pre>".Dumper($ttvars)."</pre>"
        if($debug);

    $ttvars->{latest_perl} = LATESTPERL;
    
    $tt2->process(
        $q->param('xml') ? "$tt2file-xml.tt2" : "$tt2file.tt2",
        $ttvars,
        sub { $q->print(@_); }
    ) || die($tt2->error());
}

sub depended_on_by {
  print "Content-type: text/".($q->param('xml') ? 'xml' : 'html')."\n\n";

  my $limit = CPANdepsUtils::concurrency_limit(
      "/tmp/$dbname/web/lock",
      15,
      ($q->param('xml') ? 'xml' : 'html')
  );
  $dbh= DBI->connect("dbi:mysql:database=$dbname", "root", "");

  check_params($q);

  my $dist = $q->param('dist');
  if(!$dist) {
    my $module = $q->param('module');

    if (!$module)
    {
      print <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE
    html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
    "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-US">
<head>
<title>The CPAN Reverse Dependency Lister</title>
<link rel="stylesheet" type="text/css" href="static/style.css" />
<link rel="search" type="application/opensearchdescription+xml" href="/static/opensearch.xml" title="Search module dependencies" />
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
<label for="dist">Distribution:</label> <input id="dist" name="dist" />
</p>

<p>
<input type="submit" value="Search" />
</p>

</form>

<h2>Find by Module</h2>

<form method="get" action="">

<p>
<label for="module">Module:</label> <input id="module" name="module" />
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

  (my $distversion = $dist) =~ s{^.*-(v?[\d_\.]+)$}{$1};

  my $depended_on_by = get_reverse_deps_from_dist($dist);

  $ttvars = {
    dist => $dist,
    distversion => $distversion,
    depended_on_by => $depended_on_by,
  };
  render($q, 'depended-on-by', $ttvars);
}

{
  # mmm, global. Will only work if this remains a CGI
  my %seen = ();

  opendir(DIR, "$home/db/reverse") || die("Can't open dir $home/db/reverse: $!");
  my %most_recent = ();
  foreach my $file (
      grep { -f $_ } map { "$home/db/reverse/$_" } reverse sort readdir(DIR)
  ) {
      $file =~ /^$home\/db\/reverse\/(.*)-v?\d[\d.]*\.dd$/;
      next if(!$1 || exists($most_recent{$1}));
      $most_recent{$1} = $file;
  }
  closedir(DIR);

  sub get_reverse_deps_from_dist {
    my $dist = shift;
    my $depth = shift || 0;
    return [] if($depth == 10);
    my $datafile = "$home/db/reverse/$dist.dd";
    if(!-e $datafile) {
      $datafile = $most_recent{$dist};
    }
  
    my $depended_on_by = [
      map {
        $seen{$_} = 1;
        {
          dist           => $_,
          depended_on_by => get_reverse_deps_from_dist($_, $depth + 1)
        }
      } grep {
        !exists($seen{$_})
      } @{ $datafile ? do $datafile : [] }
    ];
  }
}

sub check_params {
  my $q = shift;

  my $checks = {
    module => qr/^[\w:]+$/,
    dist   => qr/^[\w\.-]+$/,
    pureperl => qr/^[01]?$/,
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
    print "Content-type: text/".($q->param('xml') ? 'xml' : 'html')."\n\n";

    my $limit = CPANdepsUtils::concurrency_limit(
        "/tmp/$dbname/web/lock",
        15,
        ($q->param('xml') ? 'xml' : 'html')
    );
    $dbh= DBI->connect("dbi:mysql:database=$dbname", "root", "");

    check_params($q);

    $ttvars = {
        perl => (
	    ($q->param('perl') eq 'latest') ? LATESTPERL :
	    $q->param('perl')               ? $q->param('perl') :
		                              LATESTPERL
        ),
        pureperl => ($q->param('pureperl') || 0),
        devperls => ($q->param('devperls') ? 1 : 0),
        os       => ($q->param('os') || ANYOS),
        # ugh, sorting versions is Hard.  Can't use version.pm here
        perls    => [ 'latest', ANYVERSION,
            reverse sort {
                my($A, $B) = map {
                    my @v = split('\.', $_);
                    $v[2] = defined($v[2]) ? $v[2] : 0;
                    $v[2] + 1000 * $v[1] + 1000000 * $v[0];
                } ($a, $b);
                $A <=> $B;
            }
            (qw(5.6 5.8 5.10 5.12 5.14 5.16 5.18 5.20 5.22 5.24 5.26), @{ do "$home/db/perls" })
        ],
        oses => [ANYOS, sort { $a cmp $b } @{ do "$home/db/oses" }],
        query_count => 0,
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
        my $ua = LWP::UserAgent->new(
            agent => "cpandeps/$VERSION",
            from => 'david@cantrell.org.uk'
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
            warning => "Acme::Mom::Yours is silly.  Stoppit.",
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
    my $incore = do {
        no warnings 'once';
        $Module::CoreList::version{0+$v}{$module};
    };
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
    md5_hex($distname) =~ /^(..)(..)/;
    my @segments = split('/', "results/$1/$2/dist:$distname/distver:$distversion/perl:$perl/os:$os_without_slashes/devperls:$devperls");
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
        push @{$ttvars->{query_params}}, [$distname, ''.$distversion];
        $sth->execute(@{(@{$ttvars->{query_params}})[-1]});
        $ttvars->{query_count}++;
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

    my $manifest = '';
    # if we have a cache file, read it
    if(-e $cachefile) {
        open(MANIFEST, $cachefile) || die("Can't read $cachefile\n");
        $manifest = <MANIFEST>;
        close(MANIFEST);
        if($manifest eq '?') { return '?' }
    } else {
        # read from interwebnet
        my $res = $ua->request(HTTP::Request->new(GET => $MANIFESTurl));
        if(!$res->is_success()) {
            open(MANIFEST, ">$cachefile") || die("Can't write $cachefile\n");
            print MANIFEST '?';
            close(MANIFEST);
            return '?';
        } else {
            $manifest = join("\n", split(/[\r\n]+/, $res->content()));
            open(MANIFEST, ">$cachefile") || die("Can't write $cachefile\n");
            print MANIFEST $manifest;
            close(MANIFEST);
        }
    }
    my $parsed_meta = read_meta (@_);
    my $ispureperl = (
        (
            (grep {
                /\.(              # .swg and .i suggested by
                    swg        |  # Jonathan Leto
                    xs         |
                    [chi]
                )(\s|$)/ix
			} split(/\n/, $manifest)) &&
            !(grep { /PurePerl/i } split(/\n/, $manifest))
        ) ||
        (grep { /^Inline/ } keys %{{getreqs($parsed_meta)}})
    ) ? 'N' : 'Y';
	return $ispureperl;
}

sub read_meta {
    my($author, $distname, $ua) = @_;
    my $METAymlfile  = "$home/db/META.yml/$distname.yml";
    my $METAjsonfile = "$home/db/META.yml/$distname.json";
    my $METAymlURL   = "http://search.cpan.org/src/$author/$distname/META.yml";
    my $METAjsonURL  = "http://search.cpan.org/src/$author/$distname/META.json";
    my $meta;
    local $/ = undef;

    # long list of if()s instead of elsifs because if the YAML::Load or JSON::decode_json
    # fails we want to try the next method. We no longer try to fetch a frech META
    # file from the CPAN if we can't read one from the cache, as the cache is
    # populated by a batch job.
    my $parsed_meta;
    if(-e $METAymlfile) {
        open(YAML, $METAymlfile) || die("Can't read $METAymlfile\n");
        $meta = <YAML>;
        close(YAML);
        $parsed_meta = eval { YAML::Load($meta); };
    }
    if(!$parsed_meta && -e $METAjsonfile) {
        open(JSON, $METAjsonfile) || die("Can't read $METAjsonfile\n");
        $meta = <JSON>;
        close(JSON);
        $parsed_meta = eval { JSON::decode_json($meta); };
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
