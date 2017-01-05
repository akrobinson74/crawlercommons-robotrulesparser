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
use Log::Log4perl qw(:easy);
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
    Log::Log4perl->easy_init();
    use_ok('WWW::CrawlerCommons::RobotRulesParser');
}

# SM Imports
########################

# BODY
########################
# Setup
#----------------------#
try {
    no warnings 'portable'; 

    # test empty rules
    my $robot_rules = create_robot_rules("Any-darn-crawler", "");
    say STDERR Data::Dumper->Dump( [$robot_rules], ['robot_rules']) if $DEBUG > 1;
    is($robot_rules->is_allowed( "http://www.domain.com/anypage.html" ), 1,
       'test empty rules');

    # test query param in disallow
    my $robots_txt =
      join( $CRLF,
        "User-agent: *",
        "Disallow: /index.cfm?fuseaction=sitesearch.results*" );
    $robot_rules = create_robot_rules("Any-darn-crawler", $robots_txt);

    say STDERR Data::Dumper->Dump([$robot_rules],['rules']) if $DEBUG > 1;

    is(
      $robot_rules->is_allowed( "http://searchservice.domain.com/index.cfm?fuseaction=sitesearch.results&type=People&qry=california&pg=2" ),
      0,
      'query param in disallow');
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

