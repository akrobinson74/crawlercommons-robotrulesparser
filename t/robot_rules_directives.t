#!/usr/bin/env perl

=pod

=head1 NAME

robot_rules_directives.t - unit test for ...

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
use Const::Fast;
use File::HomeDir;
use Path::Tiny;
use Test::Most;
use Try::Tiny;

# VARIABLES/CONSTANTS
########################
const my $DEBUG                 => $ENV{DEBUG} // 1;
const my $TEST                  => $ENV{TEST} // 1;

# RUNTIME CONFIGURATION
########################
BEGIN {
    use_ok('WWW::CrawlerCommons::RobotRulesParser');
}

# SM Imports
########################

# BODY
########################
# Setup
#----------------------#
try {
    my $map = WWW::CrawlerCommons::RobotDirective->directive_map;
    say Data::Dumper->Dump([$map],['map']);
}
catch {
    say "Testing ended unexpectedly: $_";
};

done_testing;


# SUBROUTINES
########################
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

