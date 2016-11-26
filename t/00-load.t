#!/usr/bin/env perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'WWW::CrawlerCommons' ) || print "Bail out!\n";
}

diag( "Testing WWW::CrawlerCommons $WWW::CrawlerCommons::VERSION, Perl $], $^X" );
