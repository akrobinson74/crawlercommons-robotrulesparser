=head1 NAME

WWW::CrawlerCommons::RobotRulesParser - 

=head1 SYNOPSIS

 use WWW::CrawlerCommons::RobotRulesParser;

=head1 DESCRIPTION


=cut

###############################################################################
package WWW::CrawlerCommons::RobotRulesParser;

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
use WWW::CrawlerCommons::RobotDirective;
use WWW::CrawlerCommons::ParseState;
use WWW::CrawlerCommons::RobotRules;
use WWW::CrawlerCommons::RobotToken;

# VARIABLES/CONSTANTS
########################################
# Constants
#------------------#
const my $DEBUG                 => $ENV{DEBUG} // 0;
const my $TEST                  => $ENV{TEST} // 0;

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

    return WWW::CrawlerCommons::RobotRules->new(
      _mode => $WWW::CrawlerCommons::RobotRules::ALLOW_ALL)
        if ( ($content // '') eq '' );

    my $content_len = length( $content );
    my $offset = 0;

    # do checks for UTF-8, UTF-16LE, UTF-16BE

    # set flags that trigger the stripping of '<' and '>' from content
    my $is_html_type = ($content_type//'') ne '' &&
      lc( $content_type ) =~ m!^text/html! ? 1 : 0;

    my $has_html = 0;
    if ( $is_html_type || ($content // '') =~ $SIMPLE_HTML_PATTERN ) {
        if ( ($content // '') =~ $USER_AGENT_PATTERN ) {
            $self->log->trace( "Found non-robots.txt HTML file: $url");

            return WWW::CrawlerCommons::RobotRules->new(
              _mode => $WWW::CrawlerCommons::RobotRules::ALLOW_ALL);
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
      WWW::CrawlerCommons::ParseState->new(
        url => $url, target_name => lc($robot_name) );

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

    my $robot_rules = $parse_state->current_rules();
    if ( $robot_rules->_crawl_delay > $MAX_CRAWL_DELAY ) {
        return WWW::CrawlerCommons::RobotRules->new(
          _mode => $WWW::CrawlerCommons::RobotRules::ALLOW_NONE );
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
        my $fixed_token = WWW::CrawlerCommons::RobotToken->new(
            data        => 'http:' . $url_fragment,
            directive   =>
            WWW::CrawlerCommons::RobotDirective->get_directive('sitemap'),
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
        my $sitemap_url = URI->new( $sitemap, URI->new( $state->url ) );
        $state->add_sitemap( $sitemap_url )
          if ( ($sitemap_url->host // '') ne '' );
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
        $state->is_skip_agents( 1 ) if $self->is_finished_agent_fields;
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
                     if (index( $target_name_split, $agent_name ) >= 0 ) {
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
    my $lower_line = lc( $line );
    my ($directive, $data) = ($lower_line =~ m!^([^:\s]+):?(?:[ \t]*(.*)|[ \t]+(.*))!);
    $directive //= '';
    $data //= '';
    $data =~ s!^\s+|\s+$!!;

    if ( $directive =~ m!^acap-! ||
         WWW::CrawlerCommons::RobotDirective->directive_exists( $directive ) ){

        my $robot_directive =
          WWW::CrawlerCommons::RobotDirective->get_directive(
            $directive =~ m!^acap-!i ? 'acap-' : $directive );  

        return WWW::CrawlerCommons::RobotToken->new(
          data => $data, directive => $robot_directive
        );
    }
    else {
        my $robot_directive =
        WWW::CrawlerCommons::RobotDirective->get_directive(
          $lower_line =~ m![ \t]*:[ \t]*(.*)! ? 'unknown' : 'missing' );

        return WWW::CrawlerCommons::RobotToken->new(
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
