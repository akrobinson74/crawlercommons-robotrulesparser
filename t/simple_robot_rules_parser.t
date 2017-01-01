#!/usr/bin/env perl

=pod

=head1 NAME

simple_robot_rules_parser.t - unit test for ...

=head1 DESCRIPTION



=cut

# MODULE IMPORTS
########################
# Pragmas
#----------------------#
use 5.10.1;
use strict;
use warnings;
use utf8;

# CPAN/Core Imports
#----------------------#
use Capture::Tiny qw(:all);
use Carp qw(verbose carp confess croak);
use Const::Fast;
use DateTime;
use File::HomeDir;
use Path::Tiny;
use Sub::Override;
use Test::Most;
use Try::Tiny;

# VARIABLES/CONSTANTS
########################
const my $DEBUG                 => $ENV{DEBUG} // 1;
const my $TEST                  => $ENV{TEST} // 1;

# RUNTIME CONFIGURATION
########################
BEGIN {
    use_ok('');
}

# SM Imports
########################

# BODY
########################
# Setup
#----------------------#
try {
    
}
catch {
    say "Testing ended unexpectedly: $_";
};

done_testing;


# SUBROUTINES
########################
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#