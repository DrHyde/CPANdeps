#!/usr/local/bin/perl

use warnings;
use strict;
use lib 'lib';

use CPANdeps;

CPANdeps::depended_on_by();
