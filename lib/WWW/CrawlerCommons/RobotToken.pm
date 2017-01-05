=head1 NAME

WWW::CrawlerCommons::RobotToken - 

=head1 SYNOPSIS

 use WWW::CrawlerCommons::RobotToken;

=head1 DESCRIPTION


=cut

###############################################################################
package WWW::CrawlerCommons::RobotToken;

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
const my $DEBUG                 => $ENV{DEBUG} // 0;
const my $TEST                  => $ENV{TEST} // 1;

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
has 'data'                      => (
    is                          => 'ro',
    isa                         => 'Str',
    required                    => 1,
);
#-----------------------------------------------------------------------------#
has 'directive'                 => (
    is                          => 'ro',
    isa                         => 'WWW::CrawlerCommons::RobotDirective',
    required                    => 1,
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