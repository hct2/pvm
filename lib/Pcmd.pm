#!/usr/bin/perl
#      $URL: https://subversion.assembla.com/svn/pvm/trunk/bin/pvm $
#     $Date: 2011-05-21 18:50:47 +0100 (Sat, 21 May 2011) $
#   $Author: lqueryvg $
# $Revision: 27 $
#
# Copyright 2011 by John Buxton, HCT Solutions Ltd, UK, All rights reserved.
# See LICENSE.txt distributed with this software for license and warranty info.



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
