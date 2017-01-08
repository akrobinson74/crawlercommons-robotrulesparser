=head1 NAME

WWW::CrawlerCommons::Robots::RobotRulesParser - 

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

 use WWW::CrawlerCommons::Robots::RobotRulesParser;

=head1 DESCRIPTION


=cut

###############################################################################
package WWW::CrawlerCommons::Robots::RobotRulesParser;

# MODULE IMPORTS
########################################
# Pragmas
#------------------#
use 5.10.1;
use strict;
use utf8;
use warnings;

# CPAN/Core
#------------------#
use Const::Fast;
use Encode qw(decode encode);
use Try::Tiny;
use URI::Escape;

# Moose Setup
#------------------#
use Moose;
use namespace::autoclean;

# Moose Pragmas
#------------------#
with 'MooseX::Log::Log4perl';

# Custom Modules
#------------------#
use WWW::CrawlerCommons::Robots::RobotDirective;
use WWW::CrawlerCommons::Robots::ParseState;
use WWW::CrawlerCommons::Robots::RobotRules;
use WWW::CrawlerCommons::Robots::RobotToken;

# VARIABLES/CONSTANTS
########################################
# Constants
#------------------#
const my $DEBUG                 => $ENV{DEBUG} // 0;
const my $TEST                  => $ENV{TEST} // 0;

const my $BLANK_DIRECTIVE_PATTERN=> qr![ \t]+(.*)!o;
const my $COLON_DIRECTIVE_PATTERN=> qr![ \t]*:[ \t]*(.*)!o;

const my $MAX_CRAWL_DELAY       => 300000;
const my $MAX_WARNINGS          => 5;
const my $SIMPLE_HTML_PATTERN   => qr!<(?:html|head|body)\s*>!is;
const my $USER_AGENT_PATTERN    => qr!user-agent:!i;

# Variables
#------------------#


# MOOSE ATTRIBUTES
########################################
# Class
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

# Instance
#-----------------------------------------------------------------------------#
has 'num_warnings'              => (
    default                     => 0,
    handles                     => {
        increment_warnings      => 'inc',
    },
    is                          => 'ro',
    isa                         => 'Int',
    traits                      => ['Counter']
);
#-----------------------------------------------------------------------------#


=head1 METHODS

=over

=cut

# METHODS
########################################
# Construction
#------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

# Class Methods
#------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

# Instance Methods
#------------------#
#-----------------------------------------------------------------------------#
=item C<< $self->parse_content($url, $content, $mime_type, $crawler_name) >>


=back

=cut
sub parse_content {
    my ($self, $url, $content, $content_type, $robot_name) = @_;

    return WWW::CrawlerCommons::Robots::RobotRules->new(
      _mode => $WWW::CrawlerCommons::Robots::RobotRules::ALLOW_ALL)
        if ( ($content // '') eq '' );

    my $content_len = length( $content );
    my $offset = 0;

    # handle UTF-8, UTF-16LE, UTF-16BE content
    if ( ($content_len >= 3) && (substr($content, 0, 1) eq "\xEF") &&
         (substr($content, 1, 1) eq "\xBB") &&
         (substr($content, 2, 1) eq "\xBF") ) {
        $offset = 3;
        $content_len -= 3;
        $content = substr( $content, 3);
        $content = decode('UTF-8', $content);
    }
    elsif ( ($content_len >= 2) && (substr($content, 0, 1) eq "\xFF") &&
         (substr($content, 1, 1) eq "\xFE") ) {
        $offset = 2;
        $content_len -= 2;
        $content = substr( $content, 2);
        $content = decode('UTF-16LE', $content);
    }
    elsif ( ($content_len >= 2) && (substr($content, 0, 1) eq "\xFE") &&
         (substr($content, 1, 1) eq "\xFF") ) {
        $offset = 2;
        $content_len -= 2;
        $content = substr( $content, 2);
        $content = decode('UTF-16BE', $content);
    }

    # set flags that trigger the stripping of '<' and '>' from content
    my $is_html_type = ($content_type // '') ne '' &&
      lc( $content_type // '') =~ m!^text/html! ? 1 : 0;

    my $has_html = 0;
    if ( $is_html_type || ($content // '') =~ $SIMPLE_HTML_PATTERN ) {
        if ( ($content // '') !~ $USER_AGENT_PATTERN ) {
            $self->log->trace( "Found non-robots.txt HTML file: $url");

            return WWW::CrawlerCommons::Robots::RobotRules->new(
              _mode => $WWW::CrawlerCommons::Robots::RobotRules::ALLOW_ALL);
        }

        else {
            if ( $is_html_type ) {
                $self->log->debug(
                  "HTML content type returned for robots.txt file: $url");
            }
            else {
                $self->log->debug("Found HTML in robots.txt file: $url");
            }

            $has_html = 1;
        }
    }

    my $parse_state =
      WWW::CrawlerCommons::Robots::ParseState->new(
        url => $url, target_name => lc($robot_name) );

    # DEBUG
    $self->log->error(Data::Dumper->Dump([$parse_state],['parse_state1']))
      if $DEBUG > 2;

    for my $line ( split( m!(?:\n|\r|\r\n|\x0085|\x2028|\x2029)!, $content) ) {
        $self->log->debug("Input Line: [$line]\n");

        # strip html tags
        $line =~ s!<[^>]+>!!g if $has_html;

        # trim comments
        if (my $hash_idx = index( $line, '#') ) {
            $line = substr($line, 0, $hash_idx ) if $hash_idx >= 0;
        }

        # trim whitespace
        $line =~ s!^\s+|\s+$!!;
        next if length( $line ) == 0;

        my $robot_token = $self->_tokenize( $line );

        do {
            $self->_handle_user_agent( $parse_state, $robot_token );
            next;
        } if $robot_token->directive->is_user_agent;

        do {
            $self->_handle_disallow( $parse_state, $robot_token );
            next;
        } if $robot_token->directive->is_disallow;

        do {
            $self->_handle_allow( $parse_state, $robot_token );
            next;
        } if $robot_token->directive->is_allow;

        do {
            $self->_handle_crawl_delay( $parse_state, $robot_token );
            next;
        } if $robot_token->directive->is_crawl_delay;

        do {
            $self->_handle_sitemap( $parse_state, $robot_token );
            next;
        } if $robot_token->directive->is_sitemap;

        do {
            $self->_handle_http( $parse_state, $robot_token );
            next;
        } if $robot_token->directive->is_http;

        do {
            $self->_report_warning(
              sprintf(
                "Unknown line in robots.txt file (size %d): %s",
                length( $content ),
                $line
              ),
              $url
            );
            $parse_state->is_finished_agent_fields( 1 );
            next;
        } if $robot_token->directive->is_missing;

        do {
            $self->_report_warning(
              sprintf(
                "Unknown directive in robots.txt file: %s",
                $line
              ),
              $url
            );
            $parse_state->is_finished_agent_fields( 1 );
            next;
        } if $robot_token->directive->is_unknown;
    }

    # DEBUG
    $self->log->error(Data::Dumper->Dump([$parse_state],['parse_state2']))
      if $DEBUG > 2;

    my $robot_rules = $parse_state->current_rules();
    if ( $robot_rules->crawl_delay > $MAX_CRAWL_DELAY ) {
        return WWW::CrawlerCommons::Robots::RobotRules->new(
          _mode => $WWW::CrawlerCommons::Robots::RobotRules::ALLOW_NONE );
    }
    else {
        $robot_rules->sort_rules;
        return $robot_rules;
    }
}
#-----------------------------------------------------------------------------#

# Private Methods
#------------------#
#-----------------------------------------------------------------------------#
sub _handle_allow_or_disallow {
    my ($self, $state, $token, $allow_or_disallow ) = @_;

    $self->log->debug(Data::Dumper->Dump([\@_],['_handle_allow_or_disallow']))
      if $DEBUG > 2;

    return if $state->is_skip_agents;

    $state->is_finished_agent_fields( 1 );

    return unless $state->is_adding_rules;

    my $path = $token->data // '';
    try {
        $path = uri_unescape( $path );
        utf8::encode( $path );
        if ( length( $path ) == 0 ) {
            $state->clear_rules;
        }
        else {
            $state->add_rule( $path, $allow_or_disallow );
        }
    }
    catch {
        $self->_report_warning(
          "Error parsing robot rules - can't decode path: $path\n$_",
          $state->url
        );
    };
}
#-----------------------------------------------------------------------------#
sub _handle_allow { shift->_handle_allow_or_disallow( @_, 1 ); }
#-----------------------------------------------------------------------------#
sub _handle_crawl_delay {
    my ($self, $state, $token) = @_;

    $self->log->debug(Data::Dumper->Dump([$state, $token],['state','token']))
      if $DEBUG > 1;

    return if $state->is_skip_agents;

    $state->is_finished_agent_fields( 1 );

    return unless $state->is_adding_rules;

    my $delay = $token->data;
    try {
        my $delay_ms = $delay * 1000;
        $state->set_crawl_delay( $delay_ms );
    }
    catch {
        $self->_report_warning(
            "Error parsing robot rules - can't decode crawl delay: $delay",
            $state->url
        );
    };
}
#-----------------------------------------------------------------------------#
sub _handle_disallow { shift->_handle_allow_or_disallow( @_, 0 ); }
#-----------------------------------------------------------------------------#
sub _handle_http {
    my ($self, $state, $token) = @_;
    my $url_fragment = $token->data;
    if ( index( $url_fragment, 'sitemap' ) ) {
        my $fixed_token = WWW::CrawlerCommons::Robots::RobotToken->new(
            data        => 'http:' . $url_fragment,
            directive   =>
            WWW::CrawlerCommons::Robots::RobotDirective
             ->get_directive('sitemap'),
        );
        $self->_handle_sitemap( $state, $fixed_token );
    }
    else {
        $self->_report_warning(
          "Fournd raw non-sitemap URL: http:$url_fragment", $state->url);
    }
}
#-----------------------------------------------------------------------------#
sub _handle_sitemap {
    my ($self, $state, $token) = @_;
    my $sitemap = $token->data;
    try {
        my $sitemap_url = URI->new_abs( $sitemap, URI->new( $state->url ) );
        my $host = $sitemap_url->host() // '';

        $self->log->debug(<<"DUMP") if $DEBUG > 1;
# _handle_sitemap
###################
sitemap     $sitemap
sitemap_url $sitemap_url
host        $host
url         ${\$state->url}
DUMP

        $state->add_sitemap( $sitemap_url->as_string ) if ( $host ne '' );
    }
    catch {
        $self->_report_warning( "Invalid URL with sitemap directive: $sitemap",
                                $state->url );
    };
}
#-----------------------------------------------------------------------------#
sub _handle_user_agent {
    my ($self, $state, $token) = @_;
    if ( $state->is_matched_real_name ) {
        $state->is_skip_agents( 1 ) if $state->is_finished_agent_fields;
        return;
    }

    if ( $state->is_finished_agent_fields ) {
        $state->is_finished_agent_fields( 0 );
        $state->is_adding_rules( 0 );
    }

    for my $target_name ( split(/,/, lc( $state->target_name ) ) ) {
         for my $agent_name ( split( m! |\t|,!, $token->data ) ) {
             ( $agent_name = lc( $agent_name // '' ) ) =~ s!^\s+|\s+$!!g;

             if ( $agent_name eq '*' && !$state->is_matched_wildcard ) {
                 $state->is_matched_wildcard( 1 );
                 $state->is_adding_rules( 1 );
             }
             elsif ($agent_name ne '') {
                 for my $target_name_split ( split(/ /, $target_name) ) {
                     if (index( $target_name_split, $agent_name ) == 0 ) {
                         $state->is_matched_real_name( 1 );
                         $state->is_adding_rules( 1 );
                         $state->clear_rules;
                         last;
                     }
                 }
             }
         }
    }
}
#-----------------------------------------------------------------------------#
sub _report_warning {
    my ($self, $msg, $url) = @_;
    $self->increment_warnings;

    my $warning_count = $self->num_warnings;
    $self->log->warn("Problem processing robots.txt for $url")
      if $warning_count == 1;

    $self->log->warn( $msg ) if $warning_count <  $MAX_WARNINGS;
}
#-----------------------------------------------------------------------------#
sub _tokenize {
    my ($self, $line) = @_;

    $self->log->debug("Parsing line: [$line]") if $DEBUG;

    my $lower_line = lc( $line );
    my ($directive) = ($lower_line =~ m!^([^:\s]+)!);
    $directive //= '';

    if ( $directive =~ m!^acap\-! ||
         WWW::CrawlerCommons::Robots::RobotDirective->directive_exists( $directive ) ){

        my ($d1, $d2);
        my $data_portion = substr($line, length( $directive ));
        $d1 = ( my $data ) = ( $data_portion =~ m!$COLON_DIRECTIVE_PATTERN! );
        $d2 = ( $data ) = ( $data_portion =~ m!$BLANK_DIRECTIVE_PATTERN! )
          unless defined $data;
        $data //= '';
        $data =~ s!^\s+|\s+$!!;

        $d1 //= '';
        $d2 //= '';

        $self->log->debug(<<"DUMP") if $DEBUG;
# _tokenize dump
#################
line            [$line]
directive       [$directive]
data_portion    [$data_portion]
d1              [$d1]
d2              [$d2]
data            [$data]
DUMP

        my $robot_directive =
          WWW::CrawlerCommons::Robots::RobotDirective->get_directive(
            $directive =~ m!^acap-!i ? 'acap-' : $directive );  

        return WWW::CrawlerCommons::Robots::RobotToken->new(
          data => $data, directive => $robot_directive
        );
    }
    else {
        my $robot_directive =
        WWW::CrawlerCommons::Robots::RobotDirective->get_directive(
          $lower_line =~ m![ \t]*:[ \t]*(.*)! ? 'unknown' : 'missing' );

        return WWW::CrawlerCommons::Robots::RobotToken->new(
          data => $line, directive => $robot_directive
        ); 
    }
}
#-----------------------------------------------------------------------------#

###############################################################################

__PACKAGE__->meta->make_immutable;

###############################################################################

1;

__END__
