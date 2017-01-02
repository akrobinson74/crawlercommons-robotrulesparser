#!/usr/bin/env perl

=pod

=head1 NAME

robot_rules_parser.t - unit test for ...

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

const my $LF                    => "\n";
const my $CR                    => "\r";
const my $CRLF                  => "\r\n";
const my $FAKE_ROBOTS_URL       => "http://domain.com";

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
    # test empty rules
    my $robot_rules = create_robot_rules("Any-darn-crawler", "");
    say Data::Dumper->Dump( [$robot_rules], ['robot_rules']);
    is($robot_rules->is_allowed( "http://www.domain.com/anypage.html" ), 1,
       'test empty rules');

}
catch {
    say "Testing ended unexpectedly: $_";
};

done_testing;


# SUBROUTINES
########################
#-----------------------------------------------------------------------------#
sub create_robot_rules ($$) {
    my ($crawler_name, $content) = @_;

    my $parser = WWW::CrawlerCommons::RobotRulesParser->new;

    return
      $parser->parse_content(
        $FAKE_ROBOTS_URL,
        $content,
        "text/plain",
        $crawler_name);
}
#-----------------------------------------------------------------------------#

