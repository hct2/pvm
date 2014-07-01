#! /usr/bin/perl

=head1 NAME

Hmc::CommandRunner - run HMC commands via SSH, caching and parsing data

=head1 DESCRIPTION

Intended to encapsulate the running, caching and parsing of HMC commands.
DRC attributes remain as flat strings; the parsing of DRC attributes is
deliberately handled elsewhere to reduce complexity of this module.

This is a base class for an HMC object.

=cut

use warnings;
use strict;

package Hmc::CommandRunner;
our ($VERSION) = (q$Revision: 39 $ =~ /(\d+)/msx);

use Pparse;
use Cache;
use Debug 'debug';

#-------------------------------------------------------------------------------
sub new {
  my ($class, $name, $user) = @_;
  if (!defined $name) {
    Carp::confess "name not supplied";
  }
  if (!defined $user) {
    Carp::confess "hmc user not supplied";
  }
  my $self = { name => $name, user => $user};
  bless ($self, $class);
  return $self;
}
#-------------------------------------------------------------------------------
sub get_name {
  my ($self) = @_;
  return $self->{name};
}
#-------------------------------------------------------------------------------
sub copy_profile_hash {
  my ($self, $href) = @_;
  my %result;
  for my $attr (keys %{$href}) {
    my $value = $href->{$attr};
    $result{$attr} = $value;
  }
  return \%result;
}
#-------------------------------------------------------------------------------
sub _build_partial_cache_filename {
  my ($args_href) = @_;

  debug('called') if (Debug::level() > 1);

  my ($hmc_name, $cache_filename, $cmd) =
    @{$args_href}{qw/hmc_name cache_filename cmd/};

  my $build_name = $args_href->{hmc_name} . '/';;
  if (defined $cache_filename) {
    $build_name .= $cache_filename;
  } else {
    $cmd =~ s/\s+/\./g;
    $build_name .= $cmd;
  }
  debug('build_name = ' . $build_name) if (Debug::level() > 1);

  return $build_name;
}

#-------------------------------------------------------------------------------

=head1 get_cmd_data

params is a hash of named args:

=over

=item cmd

command to be run on this HMC

=item cache_filename

cache filename path to be used. The same path will be used under
processed and raw.

=item key

Primary key to be used for processed data.

=back

Runs command on this hmc, only if there is no data currently cached
in memory and no current & valid processed or raw file cache.
If command needs to be run,
the resulting data is parsed into a hash indexed by the specified primary key.

Returns a ref to hash containing the data. A reference to the data
is stored internally so that a subsequent request for the same command
data (same HMC name, etc) will just return a reference to the
same data in memory.

=cut

sub get_cmd_data {
  my ($self, %args) = @_;
  my ($cmd, $cache_filename, $key) =
    @args{qw/cmd cache_filename key/};

  debug('called') if (Debug::level() > 1);

  if (!defined $cmd ) {
    Carp::confess 'no cmd supplied';
  }

  debug("cmd = $cmd") if (Debug::level() > 1);

  if (Debug::level() > 1) {
    # TODO cache_filename may be undef
    debug("cache_filename = $cache_filename");
    if (defined $key) {
      debug("key = $key");
    } else {
      debug("key = undef");
    }
  }

  # prepend ssh command
  my ($hmc_user, $hmc_name) = @{$self}{qw/user name/};
  $cmd = "ssh -n $hmc_user\@$hmc_name " . $cmd;
  debug('cmd = ' . $cmd) if (Debug::level());

  $args{cmd} = $cmd;
  my $cache_filename_builder_callback_data = {
    cmd => $cmd,
    hmc_name => $hmc_name,
    cache_filename => $cache_filename,
  };

  return Cache::get_cmd_data(
    cmd => $cmd,
    user_cache_filename_builder => \&_build_partial_cache_filename,
    user_cache_filename_builder_callback_data
      => $cache_filename_builder_callback_data,
    user_process_fn => \&_parse_lines,
    user_process_fn_callback_data => $key,
  );
}

#-------------------------------------------------------------------------------
sub _parse_lines {
  my ($linesArrayRef, $primary_key) = @_;

  debug('called') if (Debug::level() > 1);

  if (!defined $primary_key) {
    $primary_key = '-';
  }
  my @keyFields = split(/,/, $primary_key);

  my $returnHashRef = {};
  my $numberOfLines = $#{$linesArrayRef} + 1;
  if ($numberOfLines == 1) {
    my $firstLine = ${$linesArrayRef}[0];
    if (!($firstLine =~ m/,/x)) {
      # No commas in a single line of output => no results
      # for this command, or the attributes requested aren't supported
      # for this managed system. Both are valid, and in this context should
      # produce empty hash.
      goto RETURN_HASH_REF;
    }
  }

  if ($primary_key eq '-' && $numberOfLines > 1) {
    Carp::confess "no primary key configured, yet there is more than one line" .
    " of data";
  }

  for my $line (@{$linesArrayRef}) {

    debug("line = $line") if (Debug::level() > 10);
    my $rec = Pparse::text_to_hash($line);

    # construct composite key
    my $keyStr;

    if ($primary_key ne '-') { # data has no primary key

      debug("primary_key = $primary_key") if (Debug::level() > 7);

      my @compositeKey;
      for my $key (@keyFields) {
	if (!defined($rec->{$key})) {
          if ($line =~ m/^HSCL/) {
              # TODO need a better way to feed back the error to user
              debug("ERROR: $line") if (Debug::level());
              return undef;
          }
	  Carp::confess
	    "key attribute \"$key\" not found in data\nline is: $line";
	}
	push @compositeKey, $rec->{$key};
      }
      $keyStr = join('/', @compositeKey);
      #debug("keyStr = $keyStr") if (Debug::level() > 2);
    } else {
      $keyStr = "-";
    }
    if (defined($returnHashRef->{$keyStr})) {
      Carp::confess "primary key value \"$keyStr\" composed of attribute(s) " .
      '"' .  join('/', @keyFields) . "\" is not unique\nline is: $line";
    }
    $returnHashRef->{$keyStr} = $rec;
    # TODO maybe delete hash fields, since same info is now in the key
  }
  RETURN_HASH_REF:

  if ($primary_key eq "-") {
    # Take out an unnecessary level of depth for commands with single
    # line of output, and therefore no primary key.
    my $saveRef = $returnHashRef->{"-"};
    delete $returnHashRef->{"-"};
    $returnHashRef = $saveRef;
  }
  return $returnHashRef;
}
#-------------------------------------------------------------------------------
sub get_hmc_version {	# TODO get rid of pvm_conf
  my ($self, $hmc) = @_;
  if (!defined($hmc)) {
    Carp::confess "hmc not defined";
  }
  debug("get_hmc_version($hmc)") if (Debug::level());
  return $self->{pvm_conf}{hmc_versions}{$hmc};
}
#-------------------------------------------------------------------------------
sub get_hmc_user {	# TODO get rid of pvm_conf
  my ($self, $hmc) = @_;
  return $self->{pvm_conf}{hmcUser};
}
#-------------------------------------------------------------------------------
sub hmc_version_supports_attribute {	# TODO get rid of pvm_conf
  my ($self, $hmc_version, $attribute) = @_;
  debug("hmc_version_supports_attribute(" .
    "$hmc_version, $attribute)") if (Debug::level());
  my $href = $self->{pvm_conf}{hmc_attribute_supported_versions};
  my $result = $hmc_version >= $href->{$attribute};
  return $result
}
#-------------------------------------------------------------------------------

1;

=head1 AUTHOR

John Buxton

