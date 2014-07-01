#! /usr/bin/perl
#      $URL: https://subversion.assembla.com/svn/pvm/trunk/pvm/lib/Debug.pm $
# $Revision: 74 $
#     $Date: 2011-11-12 12:19:20 +0000 (Sat, 12 Nov 2011) $
#   $Author: lqueryvg $
#
# Copyright 2011 by John Buxton, HCT Solutions Ltd, UK, All rights reserved.
# See LICENSE.txt distributed with this software for license and warranty info.


use warnings;
use strict;
package Debug;

our ($VERSION) = (q$Revision: 74 $ =~ /(\d+)/msx);

use base 'Exporter';

our @EXPORT_OK = qw{debug whoami};

sub whoami  { ( caller(1) )[3] }
sub whowasi  { ( caller(2) )[3] }

my $level = 0;

sub debug {
  my (@args) = @_;
  my $whowasi = whowasi();
  if (defined($whowasi)) {
    print "DEBUG: $whowasi() ", @args, "\n";
  } else {
    print 'DEBUG: ', @args, "\n";
  }
  return;
}

sub set_level {
  my ($new_level) = @_;
  $level = $new_level;
  return;
}

sub level {
  return $level;
}

1;
