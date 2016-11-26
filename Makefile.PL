use 5.006;
use strict;
use warnings;
use inc::Module::Install;

name     'WWW-CrawlerCommons';
all_from 'lib/WWW/CrawlerCommons.pm';
author   q{Adam K Robinson <akrobinson74@gmail.com>};
license  'artistic2';

perl_version 5.006;

tests_recursive('t');

resources (
   #homepage   => 'http://yourwebsitehere.com',
   #IRC        => 'irc://irc.perl.org/#WWW-CrawlerCommons',
   license    => 'http://www.perlfoundation.org/artistic_license_2_0',
   #repository => 'git://github.com/Adam K Robinson/WWW-CrawlerCommons.git',
   #repository => 'https://bitbucket.org/Adam K Robinson/WWW-CrawlerCommons',
   bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-CrawlerCommons',
);

configure_requires (
   'Module::Install' => 0,
);

build_requires (
   'Test::More' => 0,
);

requires (
   #'ABC'              => 1.6,
   #'Foo::Bar::Module' => 5.0401,
);

install_as_cpan;
auto_install;
WriteAll;
