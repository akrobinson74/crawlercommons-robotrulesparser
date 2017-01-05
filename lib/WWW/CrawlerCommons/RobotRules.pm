=head1 NAME

WWW::CrawlerCommons::RobotRules - 

=head1 SYNOPSIS

 use WWW::CrawlerCommons::RobotRules;

=head1 DESCRIPTION


=cut

###############################################################################
package WWW::CrawlerCommons::RobotRules;

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
use URI;
use URI::Escape;

# Moose Setup
#------------------#
use Moose;
use namespace::autoclean;

# Moose Pragmas
#------------------#

# Custom Modules
#------------------#



# VARIABLES/CONSTANTS
########################################
# Debug Constants
#------------------#
const my $DEBUG                 => $ENV{DEBUG} // 0;
const my $TEST                  => $ENV{TEST} // 1;

const our $ALLOW_ALL            => 'allow_all';
const our $ALLOW_NONE           => 'allow_none';
const our $ALLOW_SOME           => 'allow_some';
const my $ROBOT_RULES_MODES     =>
  ["$ALLOW_ALL", "$ALLOW_NONE", "$ALLOW_SOME"];

# Constants
#------------------#

# Variables
#------------------#

# ATTRIBUTES
########################################
# Class
#------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

# Instance
#------------------#
#-----------------------------------------------------------------------------#
has '_crawl_delay'              => (
    default                     => sub {use bigint; -2 ** 63;},
    is                          => 'rw',
    isa                         => 'Math::BigInt',
    writer                      => 'set_crawl_delay',
);
#-----------------------------------------------------------------------------#
has '_defer_visits'             => (
    default                     => 0,
    is                          => 'rw',
    isa                         => 'Bool',
    traits                      => ['Bool'],
);
#-----------------------------------------------------------------------------#
has '_mode'                     => (
    enum                        => $ROBOT_RULES_MODES,
    handles                     => 1,
    is                          => 'ro',
    required                    => 1,
    traits                      => ['Enumeration'],
);
#-----------------------------------------------------------------------------#
has '_rules'                    => (
    default                     => sub {[]},
    handles                     => {
        '_add'                  => 'push',
        'clear_rules'           => 'clear',
        '_get_rules'            => 'elements',
        '_sort_rules'           => 'sort',
    },
    is                          => 'ro',
    isa                         => 'ArrayRef[WWW::CrawlerCommons::RobotRule]',
    traits                      => ['Array'],
);
#-----------------------------------------------------------------------------#
has '_sitemaps'                 => (
    default                     => sub {[]},
    handles                     => {
        add_sitemap             => 'push',
        get_sitemaps            => 'elements',
    },
    is                          => 'ro',
    isa                         => 'ArrayRef[Str]',
    traits                      => ['Array'],
);
#-----------------------------------------------------------------------------#

# METHODS
########################################
# Constructor
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
sub add_rule {
    my ($self, $prefix, $allow) = @_;
    $allow = 1 if !$allow && length($prefix) == 0;
    $self->_add(
      WWW::CrawlerCommons::RobotRule->new( 
        _prefix => $prefix, _allow => $allow )
    );
}
#-----------------------------------------------------------------------------#
sub is_allowed {
    my ($self, $url) = @_;
    return 0 if $self->is_allow_none;
    return 1 if $self->is_allow_all;
    my $path_with_query = $self->_get_path( $url, 1);

    # always allow robots.txt
    return 1 if $path_with_query eq '/robots.txt';

    for my $rule ($self->_get_rules) {
        return $rule->_allow
          if $self->_rule_matches( $path_with_query, $rule->_prefix );
    }

    return 1;
}
#-----------------------------------------------------------------------------#
sub sort_rules {
    return shift->_sort_rules( 
      sub {
          length( $_[0]->_prefix ) <=> length( $_[1]->_prefix ) ||
            $_[1]->_allow <=> $_[0]->_allow;
      }
    );
}
#-----------------------------------------------------------------------------#

# Private Methods
#------------------#
#-----------------------------------------------------------------------------#
sub _get_path() {
    my ($self, $url, $with_query) = @_;

    try {
        my $uri = URI->new( $url );
        my $path = $uri->path();
        my $path_query = $uri->path_query() // '';

        $path = $path_query if ($with_query && $path_query ne ''); 

        if (not(defined($path)) || $path eq '') {
            return '/';
        }
        else {
            $path = uri_unescape( $path );
            utf8::encode( $path );
            return $path;
        }
    }
    catch {
        return '/';
    };
}
#-----------------------------------------------------------------------------#
sub _rule_matches {
    my ($self, $text, $pattern) = @_;
    my $pattern_pos = my $text_pos = 0;
    my $pattern_end = length( $pattern );
    my $text_end = length( $text );

    my $contains_end_char = $pattern =~ m!\$! ? 1 : 0;
    $pattern_end -= 1 if $contains_end_char;

    while ( ( $pattern_pos < $pattern_end ) && ( $text_pos < $text_end ) ) {
        my $wildcard_pos = index( $pattern, '*', $pattern_pos );
        $wildcard_pos = $pattern_end if $wildcard_pos == -1;

        say STDERR <<"DUMP" if $DEBUG > 2;
# _rule_matches wildcard...
############################
pattern         $pattern
pattern_end     $pattern_end
wildcard_pos    $wildcard_pos
DUMP

        if ( $wildcard_pos == $pattern_pos ) {
            $pattern_pos += 1;
            return 1 if $pattern_pos >= $pattern_end;

            my $pattern_piece_end = index( $pattern, '*', $pattern_pos);
            $pattern_piece_end = $pattern_end if $pattern_piece_end == -1;

            my $matched = 0;
            my $pattern_piece_len = $pattern_piece_end - $pattern_pos;
            while ( ( $text_pos + $pattern_piece_len <=  $text_end )
                    && !$matched ) {

                $matched = 1;

                for ( my $i = 0; $i < $pattern_piece_len && $matched; $i++ ) {
                    $matched = 0
                      if substr( $text, $text_pos + $i, 1 ) ne
                        substr( $pattern, $pattern_pos + $i, 1 );
                }

                $text_pos += 1 unless $matched;
            }

            return 0 unless $matched;
        }

        else {
            while ( ( $pattern_pos < $wildcard_pos ) &&
                    ( $text_pos < $text_end ) ) {

                # DEBUG
                say STDERR <<"DUMP" if $DEBUG > 2;
# _rule_matches dump
#####################
text        $text
text_pos    $text_pos
pattern     $pattern
pattern_pos $pattern_pos
DUMP
                return 0 if substr( $text, $text_pos++, 1) ne
                  substr( $pattern, $pattern_pos++, 1);
            }
        }
    }

    while ( ( $pattern_pos < $pattern_end ) &&
            ( substr( $pattern, $pattern_pos, 1 ) eq '*' ) ) {
        $pattern_pos++;
    }

    return ( $pattern_pos == $pattern_end ) &&
        ( ( $text_pos == $text_end ) || !$contains_end_char ) ? 1 : 0;
}
#-----------------------------------------------------------------------------#
###############################################################################

__PACKAGE__->meta->make_immutable;

###############################################################################

=head1 NAME

WWW::CrawlerCommons::RobotRule - 

=head1 SYNOPSIS

 use WWW::CrawlerCommons::RobotRule;

=head1 DESCRIPTION


=cut

###############################################################################
package WWW::CrawlerCommons::RobotRule;

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

# Moose Setup
#------------------#
use Moose;
use namespace::autoclean;

# Moose Pragmas
#------------------#

# Custom Modules
#------------------#



# VARIABLES/CONSTANTS
########################################
# Debug Constants
#------------------#

# Constants
#------------------#

# Variables
#------------------#

# ATTRIBUTES
########################################
# Class
#------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

# Instance
#------------------#
#-----------------------------------------------------------------------------#
has '_allow'                    => (
    is                          => 'ro',
    isa                         => 'Bool',
    required                    => 1,
);
#-----------------------------------------------------------------------------#
has '_prefix'                   => (
    is                          => 'ro',
    isa                         => 'Str',
);
#-----------------------------------------------------------------------------#

# METHODS
########################################
# Constructor
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
#-----------------------------------------------------------------------------#

# Private Methods
#------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
###############################################################################

__PACKAGE__->meta->make_immutable;

###############################################################################

1;

__END__