#!/usr/bin/perl
#      $URL: https://subversion.assembla.com/svn/pvm/trunk/pvm/lib/Cache.pm $
#     $Date: 2011-09-19 17:38:11 +0100 (Mon, 19 Sep 2011) $
#   $Author: lqueryvg $
# $Revision: 67 $
#
# Copyright 2011 by John Buxton, HCT Solutions Ltd - UK, All rights reserved.
# See LICENSE.txt distributed with this software for license and warranty info.

use warnings;
use strict;

package Cache;
our ($VERSION) = (q$Revision: 67 $ =~ /(\d+)/msx);

use Debug 'debug';
use Utils;

# Cache flush levels.
# Each command can be given a cache level (default = 1).
# Higher numbers are safer from being flushed.
# Lower numbers are more likely to get flushed.
# 

my $self = {
    memory_cache => { },
    default_max_age => 3600,   # 1 hour
    flush_level     => 0,      # by default, nothing is flushed
    always_valid    => 0,      # set to 1 for testing
    last_cmd_status => 0,      # stores exit status of most recent command

    root        => $ENV{HOME} . '/.pvmcache',   # cache root
};
#-------------------------------------------------------------------------------
sub set_root {
  my ($value) = @_;
  $self->{root} = $value;
  return;
}
#-------------------------------------------------------------------------------
sub get_root {
  return $self->{root};
}
#-------------------------------------------------------------------------------
sub set_always_valid {
  my ($value) = @_;
  $self->{always_valid} = $value;
  return;
}
#-------------------------------------------------------------------------------
sub set_flush_level {
  my ($new_level) = @_;
  $self->{flush_level} = $new_level;
  return;
}
#-------------------------------------------------------------------------------

sub _populate_filenames {
  my ($args) = @_;
  #my $file = $args->{cache_filename};
  my $file;
  my $user_cache_filename_builder = $args->{user_cache_filename_builder};
  if (defined $user_cache_filename_builder) {
    $file = $user_cache_filename_builder->(
      $args->{user_cache_filename_builder_callback_data}
    );
  } else {
    $file = $args->{cmd};
    $file =~ s@ @.@g;
  }
  $args->{raw_file} = $self->{root} . '/raw/' . $file;
  $args->{processed_file} = $self->{root} . '/processed/' . $file;
  return;
}
#-------------------------------------------------------------------------------
sub _file_is_valid {
  my ($args, $file_type) = @_;
  my $file;
  debug('file_type = ' . $file_type) if (Debug::level() > 2);
  if ($file_type eq 'processed') {
    $file = $args->{processed_file};
  } elsif ($file_type eq 'raw') {
    $file = $args->{raw_file};
  } else {
    Carp::confess 'invalid file_type';
  }
  if (Debug::level() > 2) {
    debug('cache file = ' . $file);
    debug('cache flush_level = ' . $self->{flush_level});
    debug('args->{max_age} = ' . $args->{max_age});
    debug('args->{cache_level} = ' . $args->{cache_level});
  }
  if ($self->{always_valid} && $file_type eq 'raw') {
    #return (-f $file);
    if (! -f $file) {
      Carp::confess('cache always_valid but file ' . $file . ' does not exist');
    } else {
      return 1;
    }
  }

  if (! -f $file) {
    debug('file does not exist') if (Debug::level() > 2);
    return 0;
  }

  if ($args->{cache_level} <= $self->{flush_level}) {
    debug('command cache level <= flush level') if (Debug::level() > 2);
    return 0;
  }

  my $file_age = Utils::get_file_age($file);
  debug("file_age = $file_age") if (Debug::level() > 2);

  if ($file_age > $args->{max_age}) {
    debug('max age exceeded') if (Debug::level() > 2);
    return 0;
  }

  return 1;
}
#-------------------------------------------------------------------------------
sub _run_command {
  my ($args) = @_;
  my $cmd = $args->{cmd};

  # TODO interactive mode

  my @lines;
  print "# $cmd\n";
  open(PIPE, "$cmd |") or die "can't open command $cmd: $!\n";
  while(<PIPE>) {
    chomp;
    push @lines, $_;
  }
  close(PIPE);
  $self->{last_cmd_status} = $?;
  debug('cmd_status = ' . $self->{last_cmd_status}) if (Debug::level());
  return \@lines;
}
#-------------------------------------------------------------------------------
sub get_cmd_data {
  my %args = ( 
    cmd => undef,
    cache_filename => undef,
    cache_level => 1, 
    fn => undef, # converts raw data lines into ref to a data structure
    max_age => $self->{default_max_age}, 
    @_,
  );

  #if (!defined($self)) {
  if (! defined $self) {
    _init();
  }

  if (!defined($args{cmd})) {
    Carp::confess 'cmd parameter is required';
  }

  # If already in memory, use that.
  my $memory_cache = $self->{memory_cache}{$args{cmd}};
  if (defined($memory_cache)) {
    debug('using memory cache') if (Debug::level());
    goto DONE;
  }

  debug('no memory cache') if (Debug::level() > 1);

  _populate_filenames(\%args);

  # If cached processed file data is still good, use that.
  if (_file_is_valid(\%args, 'processed')) {
    debug('processed file is valid') if (Debug::level() > 2);
    $memory_cache = Utils::restore_data($args{processed_file});
    goto DONE;
  }

  debug('processed file NOT valid') if (Debug::level() > 2);

  # Get raw data lines, either from raw cache file
  # or by running command.
  my $lines;
  if (!_file_is_valid(\%args, 'raw')) {
    debug('need raw file ' . $args{raw_file}) if (Debug::level() > 2);
    $lines = _run_command(\%args);
    debug('lines returned ' . scalar @{$lines}) if (Debug::level() > 2);
    Utils::write_file(file => $args{raw_file}, lines => $lines);
  } else {
    debug('raw file is valid') if (Debug::level() > 2);
    $lines = Utils::read_file($args{raw_file});
  }

  # Process the raw data into memory structure.
  if (!defined($args{user_process_fn})) {
    debug('no user defined processing function') if (Debug::level() > 2);
    # if there is no user defined processing function,
    # default behaviour is just to store ref to array of lines
    $memory_cache = $lines;
  } else {
    debug('calling user processing function') if (Debug::level() > 2);
    $memory_cache = $args{user_process_fn}
      ->($lines, $args{user_process_fn_callback_data});
  }

  # Save processed data to cache file.
  Utils::save_data($args{processed_file}, $memory_cache);

  DONE:
  $self->{memory_cache}{$args{cmd}} = $memory_cache;
  return $memory_cache;
}

1;
