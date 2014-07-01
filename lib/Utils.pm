#!/usr/bin/perl
#      $URL: https://subversion.assembla.com/svn/pvm/trunk/pvm/lib/Utils.pm $
#   $Author: lqueryvg $
#     $Date: 2011-09-19 17:38:11 +0100 (Mon, 19 Sep 2011) $
# $Revision: 67 $
#
# Copyright 2011 by John Buxton, HCT Solutions Ltd, UK, All rights reserved.
# See LICENSE.txt distributed with this software for license and warranty info.



use warnings;
use strict;
use Carp;

package Utils;

our ($VERSION) = (q$Revision: 67 $ =~ /(\d+)/msx);


#-------------------------------------------------------------------------
sub mkdir_minus_p {
  my ($dir) = @_;

  #my @pathElements = split("/", $dir);
  my $path = "";
  foreach (split("/", $dir)) {
    $path .= "$_/";
    if (! -d $path) {
      print "# mkdir $path\n";
      if (! mkdir $path) {
        die "mkdir failed for $path: $!\n";
      }
    }
  }
}
#-------------------------------------------------------------------------
sub get_file_age {
  my ($filename) = @_;
  use File::stat;
  my $statbuf = stat($filename) or Carp::confess "stat failed $filename: $!";
  my $now = time;
  my $filetime =  $statbuf->mtime;
  my $fileage = $now - $filetime;
  return $fileage;
}
#-------------------------------------------------------------------------
sub write_file {
  my (%args) = @_;
  #use Data::Dumper;
  #print Dumper(\%args);
  my ($file, $lines) = @args{"file", "lines"};
  if (!defined($file)) {
    Carp::confess "file not defined";
  }
  use File::Basename;
  mkdir_minus_p(dirname($file));

  if (!defined($lines)) {
    Carp::confess "lines not defined";
  }
  open(OUTPUT, "> $file") or Carp::confess "failed to open $file for write: $!";
  for my $line (@$lines) {
    print OUTPUT "$line\n";
  }
  close OUTPUT or die "close failed for $file: $!";
}
#-------------------------------------------------------------------------
sub read_file {
  my ($filename) = @_;
  my @lines;

  if (!open(FILE, $filename)) {
    die "ERROR: unable to open $filename: $!";
    return @lines;
  }
  while (defined(my $line = <FILE>)) {
    chomp $line;
    push @lines, $line;
  }
  close(FILE);
  return \@lines;
}
#-------------------------------------------------------------------------
sub get_tmp_filename {
  my ($base) = @_;
  my $whoami = `whoami`;
  chomp($whoami);
  return "/tmp/$base.$whoami.tmp";
}
#-------------------------------------------------------------------------
sub write_string_to_file {
  my ($string, $filename) = @_;
  write_file(file => $filename, lines => [$string]);
}
#-------------------------------------------------------------------------
sub scp {
  my ($src, $dst) = @_;
  my @cmd = ("/bin/echo", "scp", $src, $dst);
  system(@cmd) == 0 or die "system() failed, command is \"" .
    join(" ", @cmd) .
    "\": $!";
}
#-------------------------------------------------------------------------
sub ssh {
  my ($user_and_host, $command) = @_;
  #print "$user_and_host\n";
  #print "$command\n";
  my @cmd = ("/bin/echo", "ssh", $user_and_host, $command);
  system(@cmd) == 0 or die "system() failed, command is \"" .
    join(" ", @cmd) .
    "\": $!";
}
#-------------------------------------------------------------------------
sub save_data {
  my ($file, $data) = @_;
  $Data::Dumper::Indent = 1;
  $Data::Dumper::Quotekeys = 0;
  $Data::Dumper::Sortkeys = 1;
  use Data::Dumper;
  my $dd = Data::Dumper->new([$data], [qw/data/]);
  write_string_to_file($dd->Dump, $file);
}
#-------------------------------------------------------------------------
sub restore_data {
  my ($file) = @_;
  my $data;
  my $file_contents = do {
    open(my $fh, '<', $file) or die "$file: $!";
    local $/; <$fh>
  };
  eval $file_contents;
  return $data;
}
#-------------------------------------------------------------------------

1;
