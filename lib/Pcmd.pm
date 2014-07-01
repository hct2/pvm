#!/usr/bin/perl



use warnings;
use strict;

package Pcmd;
our ($VERSION) = (q$Revision: 27 $ =~ /(\d+)/msx);

use FindBin qw($Bin);
use lib "$Bin/../lib";

our $pcmd_conf;
my $config_file = "pcmd.conf";
require $config_file;
if (!defined($pcmd_conf)) {
  die "error reading $config_file, \$pcmd_conf still undefined";
}

sub get {
  return $pcmd_conf;
}

sub get_conf {
  my ($base_user_command) = @_;
#  my $ref = $pcmd_conf->{$base_user_command};
#  Carp::confess "no template defined for command '$base_user_command'"
#    if (! defined $ref->{template});
  return $pcmd_conf->{$base_user_command};
}

1;
