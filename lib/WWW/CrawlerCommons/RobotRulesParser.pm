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
# Constants
#------------------#
const my $DEBUG                 => $ENV{DEBUG} // 0;
const my $TEST                  => $ENV{TEST} // 0;



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
    is                          => 'ro',
    isa                         => 'Counter',
);
#-----------------------------------------------------------------------------#


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
sub parse_content {
    my ($self, $url, $content, $content_type, $robot_name) = @_;
}
#-----------------------------------------------------------------------------#

# Private Methods
#------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

###############################################################################

__PACKAGE__->meta->make_immutable;

###############################################################################

=head1 NAME

WWW::CrawlerCommons::RobotRulesParser - 

=head1 SYNOPSIS

 use WWW::CrawlerCommons::RobotRulesParser;

=head1 DESCRIPTION


=cut

###############################################################################
package WWW::CrawlerCommons::RobotDirective;

# MODULE IMPORTS
########################################
# Pragmas
#------------------#

# CPAN/Core
#------------------#
use Const::Fast;

# Moose Setup
#------------------#

# Moose Pragmas
#------------------#
use Moose;
use MooseX::ClassAttribute;
use namespace::autoclean;

# Custom Modules
#------------------#


# VARIABLES/CONSTANTS
########################################
# Constants
#------------------#
const my $CRAWLDELAY_MISSPELLINGS=>["crawl delay"];
const my $DISALLOW_MISSPELLINGS => [qw(desallow dissalow dssalow dsallow)];
const my $DIRECTIVES_LIST       =>
  [qw(USER_AGENT DISALLOW ALLOW CRAWL_DELAY SITEMAP HOST NO_INDEX REQUEST_RATE
      VISIT_TIME ROBOT_VERSION COMMENT HTTP)];
const my $DIRECTIVE_PREFIX_MAP  => __PACKAGE__->load_directives_map;
const my $PREFIX_DIRECTIVES     => [qw(ACAP_)];
const my $SPECIAL_DIRECTIVES    => [qw(UNKNOWN MISSING)];
const my $USERAGENT_MISSPELLINGS=> [qw(useragent useg-agent ser-agent)];

# Variables
#------------------#


# MOOSE ATTRIBUTES
########################################
# Class
#-----------------------------------------------------------------------------#
class_has 'directive_map'       => (
    builder                     => 'load_directives_map',
    is                          => 'ro',
    isa                         => 'HashRef',
    lazy                        => 1,
);
#-----------------------------------------------------------------------------#

# Instance
#-----------------------------------------------------------------------------#
has 'is_prefix'                 => (
    default                     => 0,
    is                          => 'ro',
    isa                         => 'Bool',
);
#-----------------------------------------------------------------------------#
has 'is_special'                => (
    default                     => 0,
    is                          => 'ro',
    isa                         => 'Bool',
);
#-----------------------------------------------------------------------------#
has 'value'                     => (
    is                          => 'ro',
    isa                         => 'Str',
    required                    => 1,
);
#-----------------------------------------------------------------------------#

# METHODS
########################################
# Construction
#------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

# Class Methods
#------------------#
#-----------------------------------------------------------------------------#
sub load_directives_map {
    my $pkg = shift;

    my $map = {
        $pkg->_map_directive_list( $DIRECTIVES_LIST, 0, 0),
        $pkg->_map_directive_list( $PREFIX_DIRECTIVES, 1, 0),
        $pkg->_map_directive_list( $SPECIAL_DIRECTIVES, 0, 1),
    };

    # setup common user_agent, disallow and crawl_delya directive misspellings
    $map->{$_} = $map->{'crawl-delay'} for @{ $CRAWLDELAY_MISSPELLINGS };
    $map->{$_} = $map->{disallow} for @{ $DISALLOW_MISSPELLINGS };
    $map->{$_} = $map->{'user-agent'} for @{ $USERAGENT_MISSPELLINGS };

    return $map;
}
#-----------------------------------------------------------------------------#

# Instance Methods
#------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

# Private Methods
#------------------#
#-----------------------------------------------------------------------------#
sub _map_directive_list {
    my ($pkg, $directives_list, $is_prefix, $is_special) = @_;
    my %map = ();

    for my $directive_str ( @{ $directives_list } ) {
        (my $prefix = lc($directive_str)) =~ s!_!\-!g;
        $map{$prefix} = $is_prefix ?
          $pkg->new(value => $directive_str, is_prefix => 1) :
            ($is_special ?
              $pkg->new(value => $directive_str, is_special => 1) :
              $pkg->new(value => $directive_str));
    }

    return %map;
}
#-----------------------------------------------------------------------------#

###############################################################################

__PACKAGE__->meta->make_immutable;

###############################################################################

=head1 NAME

WWW::CrawlerCommons::ParseState - 

=head1 SYNOPSIS

 use lib::WWW::CrawlerCommons::ParseState;

=head1 DESCRIPTION


=cut
###############################################################################
package WWW::CrawlerCommons::ParseState;

# MODULE IMPORTS
########################################
# Pragmas
#------------------#

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
# Constants
#------------------#

# Variables
#------------------#


# MOOSE ATTRIBUTES
########################################
# Class
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#

# Instance
#-----------------------------------------------------------------------------#
has 'current_rules'             => (
    default                     => sub {WWW::CrawlerCommons::RobotRules->new},
    is                          => 'ro',
    isa                         => 'WWW::CrawlerCommons::RobotRules',
);
#-----------------------------------------------------------------------------#
has 'is_adding_rules'           => (
    is                          => 'rw',
    isa                         => 'Bool',
);
#-----------------------------------------------------------------------------#
has 'is_finished_agent_fields'  => (
    is                          => 'rw',
    isa                         => 'Bool',
);
#-----------------------------------------------------------------------------#
has 'is_matched_real_name'      => (
    is                          => 'rw',
    isa                         => 'Bool',
);
#-----------------------------------------------------------------------------#
has 'is_matched_wildcard'       => (
    is                          => 'rw',
    isa                         => 'Bool',
);
#-----------------------------------------------------------------------------#
has 'is_skip_agents'            => (
    is                          => 'rw',
    isa                         => 'Bool',
);
#-----------------------------------------------------------------------------#
has 'target_name'               => (
    is                          => 'ro',
    isa                         => 'Str',
    required                    => 1,
);
#-----------------------------------------------------------------------------#
has 'url'                       => (
    is                          => 'ro',
    isa                         => 'Str',
    required                    => 1,
);
#-----------------------------------------------------------------------------#

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