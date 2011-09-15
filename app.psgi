#!/usr/bin/env perl

# DO NOT USE!!!!
# This is just for doing design testing stuff
# I am testing 
use strict;
use warnings;
use lib qw(/home/kam/git/Plack-Middleware-TemplateToolkit/lib);
use Plack::Builder;
use Plack::Middleware::Static;
use Plack::Middleware::TemplateToolkit;


my $chooser = sub {
    my $req = shift;

    if($req->path_info() =~ /cpand/) {
        cpandebs();
    } else {
        depends_on();
    }
};

# Create our TT app, specifying the root and file extensions
my $app = Plack::Middleware::TemplateToolkit->new(
    INCLUDE_PATH => './templates',    # required
    vars         => $chooser,
    dir_index => 'design.html',
)->to_app;

# Binary files can be served directly
$app = Plack::Middleware::Static->wrap(
    $app,
    path => qr{^/static},
    root => './'
);

return builder {
    $app;
};




sub depends_on {
    return {
        'datafile' =>
            '/web/cpandeps-dev.cantrell.org.uk/db/reverse/Module-Load-Conditional-0.44.dd',
        'depended_on_by' => [
            'Archive-Extract',
            'Archive-SimpleExtractor',
            'Audio-Nama',
            'CHI',
            'CPANPLUS-Dist-Build',
            'CPANPLUS-Dist-Deb',
            'CPANPLUS-Dist-PAR',
            'CPANPLUS-Internals-Source-CPANIDX',
            'CPANPLUS-Internals-Source-CPANMetaDB',
            'CPANPLUS-Shell-Wx',
            'CPANPLUS-YACSmoke',
            'Dist-Zooky',
            'File-Fetch',
            'IPC-Cmd',
            'Log-Dispatch-DesktopNotification',
            'Markup-Unified',
            'Net-FullAuto',
            'PLUTO',
            'RDF-Trine',
            'Task-CPANPLUS-Metabase',
            'Term-Menus',
            'Term-Size-Any',
            'VCI',
            'metabase-relayd',
            'smokebrew'
        ],
        'dist'    => 'Module-Load-Conditional-0.44',
        'modules' => []
    };

}

sub cpandebs {
    return {
        'devperls' => 0,
        'module'   => 'Sub::WrapPackages',
        'modules'  => [
            {   'CPANfile' => 'D/DC/DCANTRELL/Sub-WrapPackages-2.0.tar.gz',
                'author'   => 'DCANTRELL',
                'distname' => 'Sub-WrapPackages',
                'fail'     => 0,
                'has_children' => 1,
                'indent'       => 0,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Sub::WrapPackages',
                'pass'         => '118',
                'unknown'      => 0,
                'version'      => '2.0',
                'warning'      => ''
            },
            {   'CPANfile'     => 'F/FL/FLORA/Sub-Prototype-0.02.tar.gz',
                'author'       => 'FLORA',
                'distname'     => 'Sub-Prototype',
                'fail'         => '1',
                'has_children' => 1,
                'indent'       => 1,
                'ispureperl'   => 'N',
                'na'           => '13',
                'name'         => 'Sub::Prototype',
                'pass'         => '289',
                'required_by'  => [ 'Sub::WrapPackages' ],
                'unknown'      => '2',
                'version'      => '0.02',
                'warning'      => ''
            },
            {   'CPANfile'     => 'S/SA/SAPER/XSLoader-0.10.tar.gz',
                'author'       => 'SAPER',
                'distname'     => 'XSLoader',
                'fail'         => '67',
                'has_children' => 1,
                'indent'       => 2,
                'ispureperl'   => '?',
                'na'           => 0,
                'name'         => 'XSLoader',
                'pass'         => '902',
                'required_by'  => [ 'Sub::WrapPackages', 'Sub::Prototype' ],
                'unknown'      => '2',
                'version'      => '0.10',
                'warning'      => ''
            },
            {   'CPANfile'     => 'M/MS/MSCHWERN/Test-Simple-0.98.tar.gz',
                'author'       => 'MSCHWERN',
                'distname'     => 'Test-Simple',
                'fail'         => '1',
                'has_children' => 1,
                'indent'       => 3,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Test::More',
                'pass'         => '279',
                'required_by' =>
                    [ 'Sub::WrapPackages', 'Sub::Prototype', 'XSLoader' ],
                'unknown' => 0,
                'version' => '0.98',
                'warning' => ''
            },
            {   'CPANfile'     => 'A/AN/ANDYA/Test-Harness-3.23.tar.gz',
                'author'       => 'ANDYA',
                'distname'     => 'Test-Harness',
                'fail'         => 0,
                'has_children' => 0,
                'indent'       => 4,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Test::Harness',
                'pass'         => '292',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'XSLoader',          'Test::More'
                ],
                'unknown' => 0,
                'version' => '3.23',
                'warning' => ''
            },
            {   'CPANfile' => 'M/MS/MSCHWERN/ExtUtils-MakeMaker-6.56.tar.gz',
                'author'   => 'MSCHWERN',
                'distname' => 'ExtUtils-MakeMaker',
                'has_children' => 0,
                'indent'       => 4,
                'ispureperl'   => '?',
                'name'         => 'ExtUtils::MakeMaker',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'XSLoader',          'Test::More'
                ],
                'textresult' => 'Core module',
                'version'    => '6.56',
                'warning'    => ''
            },
            {   'CPANfile'     => 'R/RJ/RJBS/Sub-Exporter-0.982.tar.gz',
                'author'       => 'RJBS',
                'distname'     => 'Sub-Exporter',
                'fail'         => '1',
                'has_children' => 1,
                'indent'       => 2,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Sub::Exporter',
                'pass'         => '2032',
                'required_by'  => [ 'Sub::WrapPackages', 'Sub::Prototype' ],
                'unknown'      => '5',
                'version'      => '0.982',
                'warning'      => ''
            },
            {   'CPANfile'     => 'A/AD/ADAMK/Params-Util-1.03.tar.gz',
                'author'       => 'ADAMK',
                'distname'     => 'Params-Util',
                'fail'         => 0,
                'has_children' => 1,
                'indent'       => 3,
                'ispureperl'   => 'N',
                'na'           => 0,
                'name'         => 'Params::Util',
                'pass'         => '632',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype', 'Sub::Exporter'
                ],
                'unknown' => '18',
                'version' => '1.03',
                'warning' => ''
            },
            {   'CPANfile'     => 'G/GB/GBARR/Scalar-List-Utils-1.23.tar.gz',
                'author'       => 'GBARR',
                'distname'     => 'Scalar-List-Utils',
                'fail'         => '14',
                'has_children' => 0,
                'indent'       => 4,
                'ispureperl'   => 'N',
                'na'           => 0,
                'name'         => 'Scalar::Util',
                'pass'         => '1079',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'Sub::Exporter',     'Params::Util'
                ],
                'unknown' => '24',
                'version' => '1.23',
                'warning' => ''
            },
            {   'CPANfile'     => 'S/SM/SMUELLER/PathTools-3.33.tar.gz',
                'author'       => 'SMUELLER',
                'distname'     => 'PathTools',
                'fail'         => '3',
                'has_children' => 1,
                'indent'       => 4,
                'ispureperl'   => 'N',
                'na'           => 0,
                'name'         => 'File::Spec',
                'pass'         => '502',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'Sub::Exporter',     'Params::Util'
                ],
                'unknown' => '19',
                'version' => '3.33',
                'warning' => ''
            },
            {   'CPANfile'     => 'D/DL/DLAND/File-Path-2.08.tar.gz',
                'author'       => 'DLAND',
                'distname'     => 'File-Path',
                'has_children' => 0,
                'indent'       => 5,
                'ispureperl'   => '?',
                'name'         => 'File::Path',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'Sub::Exporter',     'Params::Util',
                    'File::Spec'
                ],
                'textresult' => 'Core module',
                'version'    => '2.08',
                'warning'    => ''
            },
            {   'CPANfile'     => 'S/SB/SBURKE/Test-1.25.tar.gz',
                'author'       => 'SBURKE',
                'distname'     => 'Test',
                'has_children' => 0,
                'indent'       => 5,
                'ispureperl'   => '?',
                'name'         => 'Test',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'Sub::Exporter',     'Params::Util',
                    'File::Spec'
                ],
                'textresult' => 'Core module',
                'version'    => '1.25',
                'warning'    => ''
            },
            {   'CPANfile'     => 'F/FL/FLORA/perl-5.13.11.tar.gz',
                'author'       => 'FLORA',
                'distname'     => 'perl',
                'has_children' => 0,
                'indent'       => 5,
                'ispureperl'   => '?',
                'name'         => 'File::Basename',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'Sub::Exporter',     'Params::Util',
                    'File::Spec'
                ],
                'textresult' => 'Core module',
                'version'    => '5.13.11',
                'warning'    => ''
            },
            {   'CPANfile' =>
                    'D/DA/DAGOLDEN/ExtUtils-CBuilder-0.280202.tar.gz',
                'author'       => 'DAGOLDEN',
                'distname'     => 'ExtUtils-CBuilder',
                'fail'         => '4',
                'has_children' => 1,
                'indent'       => 4,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'ExtUtils::CBuilder',
                'pass'         => '284',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'Sub::Exporter',     'Params::Util'
                ],
                'unknown' => 0,
                'version' => '0.280202',
                'warning' => ''
            },
            {   'CPANfile'     => 'G/GB/GBARR/IO-1.25.tar.gz',
                'author'       => 'GBARR',
                'distname'     => 'IO',
                'has_children' => 0,
                'indent'       => 5,
                'ispureperl'   => '?',
                'name'         => 'IO::File',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'Sub::Exporter',     'Params::Util',
                    'ExtUtils::CBuilder'
                ],
                'textresult' => 'Core module',
                'version'    => '1.25',
                'warning'    => ''
            },
            {   'CPANfile'     => 'B/BI/BINGOS/IPC-Cmd-0.70.tar.gz',
                'author'       => 'BINGOS',
                'distname'     => 'IPC-Cmd',
                'fail'         => '8',
                'has_children' => 1,
                'indent'       => 5,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'IPC::Cmd',
                'pass'         => '274',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'Sub::Exporter',     'Params::Util',
                    'ExtUtils::CBuilder'
                ],
                'unknown' => 0,
                'version' => '0.70',
                'warning' => ''
            },
            {   'CPANfile' => 'J/JE/JESSE/Locale-Maketext-Simple-0.21.tar.gz',
                'author'   => 'JESSE',
                'distname' => 'Locale-Maketext-Simple',
                'fail'     => '1',
                'has_children' => 0,
                'indent'       => 6,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Locale::Maketext::Simple',
                'pass'         => '802',
                'required_by'  => [
                    'Sub::WrapPackages',  'Sub::Prototype',
                    'Sub::Exporter',      'Params::Util',
                    'ExtUtils::CBuilder', 'IPC::Cmd'
                ],
                'unknown' => 0,
                'version' => '0.21',
                'warning' => ''
            },
            {   'CPANfile' =>
                    'B/BI/BINGOS/Module-Load-Conditional-0.44.tar.gz',
                'author'       => 'BINGOS',
                'distname'     => 'Module-Load-Conditional',
                'fail'         => 0,
                'has_children' => 1,
                'indent'       => 6,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Module::Load::Conditional',
                'pass'         => '259',
                'required_by'  => [
                    'Sub::WrapPackages',  'Sub::Prototype',
                    'Sub::Exporter',      'Params::Util',
                    'ExtUtils::CBuilder', 'IPC::Cmd'
                ],
                'unknown' => 0,
                'version' => '0.44',
                'warning' => ''
            },
            {   'CPANfile'     => 'B/BI/BINGOS/Module-Load-0.18.tar.gz',
                'author'       => 'BINGOS',
                'distname'     => 'Module-Load',
                'fail'         => 0,
                'has_children' => 0,
                'indent'       => 7,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Module::Load',
                'pass'         => '744',
                'required_by'  => [
                    'Sub::WrapPackages',  'Sub::Prototype',
                    'Sub::Exporter',      'Params::Util',
                    'ExtUtils::CBuilder', 'IPC::Cmd',
                    'Module::Load::Conditional'
                ],
                'unknown' => '2',
                'version' => '0.18',
                'warning' => ''
            },
            {   'CPANfile'     => 'J/JP/JPEACOCK/version-0.88.tar.gz',
                'author'       => 'JPEACOCK',
                'distname'     => 'version',
                'fail'         => '1',
                'has_children' => 1,
                'indent'       => 7,
                'ispureperl'   => 'N',
                'na'           => 0,
                'name'         => 'version',
                'pass'         => '538',
                'required_by'  => [
                    'Sub::WrapPackages',  'Sub::Prototype',
                    'Sub::Exporter',      'Params::Util',
                    'ExtUtils::CBuilder', 'IPC::Cmd',
                    'Module::Load::Conditional'
                ],
                'unknown' => '4',
                'version' => '0.88',
                'warning' => ''
            },
            {   'CPANfile'     => 'T/TJ/TJENNESS/File-Temp-0.22.tar.gz',
                'author'       => 'TJENNESS',
                'distname'     => 'File-Temp',
                'fail'         => '1',
                'has_children' => 0,
                'indent'       => 8,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'File::Temp',
                'pass'         => '1028',
                'required_by'  => [
                    'Sub::WrapPackages',         'Sub::Prototype',
                    'Sub::Exporter',             'Params::Util',
                    'ExtUtils::CBuilder',        'IPC::Cmd',
                    'Module::Load::Conditional', 'version'
                ],
                'unknown' => 0,
                'version' => '0.22',
                'warning' => ''
            },
            {   'CPANfile'     => 'B/BI/BINGOS/Module-CoreList-2.46.tar.gz',
                'author'       => 'BINGOS',
                'distname'     => 'Module-CoreList',
                'fail'         => 0,
                'has_children' => 0,
                'indent'       => 7,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Module::CoreList',
                'pass'         => '147',
                'required_by'  => [
                    'Sub::WrapPackages',  'Sub::Prototype',
                    'Sub::Exporter',      'Params::Util',
                    'ExtUtils::CBuilder', 'IPC::Cmd',
                    'Module::Load::Conditional'
                ],
                'unknown' => 0,
                'version' => '2.46',
                'warning' => ''
            },
            {   'CPANfile'     => 'B/BI/BINGOS/Params-Check-0.28.tar.gz',
                'author'       => 'BINGOS',
                'distname'     => 'Params-Check',
                'fail'         => 0,
                'has_children' => 0,
                'indent'       => 7,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Params::Check',
                'pass'         => '313',
                'required_by'  => [
                    'Sub::WrapPackages',  'Sub::Prototype',
                    'Sub::Exporter',      'Params::Util',
                    'ExtUtils::CBuilder', 'IPC::Cmd',
                    'Module::Load::Conditional'
                ],
                'unknown' => 0,
                'version' => '0.28',
                'warning' => ''
            },
            {   'CPANfile'     => 'C/CH/CHORNY/Text-ParseWords-3.27.zip',
                'author'       => 'CHORNY',
                'distname'     => 'Text-ParseWords',
                'has_children' => 0,
                'indent'       => 5,
                'ispureperl'   => '?',
                'name'         => 'Text::ParseWords',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype',
                    'Sub::Exporter',     'Params::Util',
                    'ExtUtils::CBuilder'
                ],
                'textresult' => 'Core module',
                'version'    => '3.27',
                'warning'    => ''
            },
            {   'CPANfile'     => 'R/RJ/RJBS/Sub-Install-0.925.tar.gz',
                'author'       => 'RJBS',
                'distname'     => 'Sub-Install',
                'fail'         => 0,
                'has_children' => 0,
                'indent'       => 3,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Sub::Install',
                'pass'         => '2060',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype', 'Sub::Exporter'
                ],
                'unknown' => '1',
                'version' => '0.925',
                'warning' => ''
            },
            {   'CPANfile'     => 'R/RJ/RJBS/Data-OptList-0.106.tar.gz',
                'author'       => 'RJBS',
                'distname'     => 'Data-OptList',
                'fail'         => 0,
                'has_children' => 0,
                'indent'       => 3,
                'ispureperl'   => 'Y',
                'na'           => 0,
                'name'         => 'Data::OptList',
                'pass'         => '1143',
                'required_by'  => [
                    'Sub::WrapPackages', 'Sub::Prototype', 'Sub::Exporter'
                ],
                'unknown' => 0,
                'version' => '0.106',
                'warning' => ''
            },
            {   'CPANfile' =>
                    'D/DC/DCANTRELL/Devel-Caller-IgnoreNamespaces-1.0.tar.gz',
                'author'      => 'DCANTRELL',
                'distname'    => 'Devel-Caller-IgnoreNamespaces',
                'fail'        => 0,
                'indent'      => 1,
                'ispureperl'  => 'Y',
                'na'          => 0,
                'name'        => 'Devel::Caller::IgnoreNamespaces',
                'pass'        => '227',
                'required_by' => [ 'Sub::WrapPackages' ],
                'unknown'     => 0,
                'version'     => '1.0',
                'warning'     => ''
            }
        ],
        'os'   => 'any OS',
        'oses' => [
            'any OS',
            'AIX',
            'BSD OS',
            'BeOS',
            'Dragonfly BSD',
            'FreeBSD',
            'FreeBSD (Debian)',
            'GNU Hurd',
            'HP-UX',
            'Haiku',
            'Irix',
            'Linux',
            'Mac OS X',
            'Mac OS classic',
            'Midnight BSD',
            'MirOS BSD',
            'NetBSD',
            'OS/2',
            'OS390/zOS',
            'OpenBSD',
            'QNX Neutrino',
            'SCO Unix',
            'Solaris',
            'Tru64/OSF/Digital UNIX',
            'Unknown OS',
            'VMS',
            'Windows (Cygwin)',
            'Windows (Win32)'
        ],
        'perl'  => 'any version',
        'perls' => [
            'any version', '5.3',    '5.4',    '5.5',
            '5.6',         '5.6.0',  '5.6.1',  '5.6.2',
            '5.7.1',       '5.7.2',  '5.7.3',  '5.8',
            '5.8.0',       '5.8.1',  '5.8.2',  '5.8.3',
            '5.8.4',       '5.8.5',  '5.8.6',  '5.8.7',
            '5.8.8',       '5.8.9',  '5.9.0',  '5.9.1',
            '5.9.2',       '5.9.3',  '5.9.4',  '5.9.5',
            '5.9.6',       '5.10',   '5.10.0', '5.10.1',
            '5.11.0',      '5.11.1', '5.11.2', '5.11.3',
            '5.11.4',      '5.11.5', '5.12.0', '5.12.1',
            '5.12.2',      '5.12.3', '5.13.0', '5.13.1',
            '5.13.2',      '5.13.3', '5.13.4', '5.13.5',
            '5.13.6',      '5.13.7', '5.13.8', '5.13.9',
            '5.14.0 RC0'
        ],
        'pureperl' => 'on',
        'query'    => '
                    SELECT state, COUNT(state) FROM cpanstats
                     WHERE dist=?
                       AND version=?
                       AND state IN (\'fail\', \'pass\', \'na\', \'unknown\')
                 AND is_dev_perl = \'0\' GROUP BY state '
    };

}
