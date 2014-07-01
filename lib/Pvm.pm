#!/usr/bin/perl
#      $URL: https://subversion.assembla.com/svn/pvm/trunk/pvm/lib/Pvm.pm $
# $Revision: 74 $
#     $Date: 2011-11-12 12:19:20 +0000 (Sat, 12 Nov 2011) $
#   $Author: lqueryvg $
#
# Copyright 2011 by John Buxton, HCT Solutions Ltd, UK, All rights reserved.
# See LICENSE.txt distributed with this software for license and warranty info.

=head1 NAME

pvm - interface to IBM PowerVM HMC/IVM commands

=head1 SUBROUTINES

=cut

use warnings;
use strict;

package Pvm;
our ($VERSION) = (q$Revision: 74 $ =~ /(\d+)/msx);

use Hmc;
use Carp;
use Report;
use Debug 'debug';
use Pcmd;
use Cache;

my $self;
our $pvm_conf;

#-------------------------------------------------------------------------
sub print_base_options_help_DELETE {
    print <<"EOF";
Base Options:
  -d     # debug
  -r     # re-read cache
  -h|-?  # help
EOF
    return;
}

#-------------------------------------------------------------------------
sub is_a_base_option_DELETE {
    my ($opt, $usage_fn) = @_;

    if ($opt eq 'd') {
        debug("debug level = " . Debug::level());
    }
    elsif ($opt eq 'h' || $opt eq '?') {
        $usage_fn->();
    }
    elsif ($opt eq 'r') {
        $Pvm::re_read_cache = 1;
    }
    else {
        return 0;
    }

    #print "return 1\n";
    return 1;
}

#-------------------------------------------------------------------------

=head1 init(configFile => string)

Initialise module based on info found in the config_file. Default file
is "pvm.conf" if not supplied. The config file is expected to set a variable
called pvm_conf which is a reference to a hash containing various
configuration information.

=cut

sub init {
    my %args = @_;
    my ($config_file) = $args{"config_file"};
    debug('called') if (Debug::level() > 1);


    #require $config_file;
    require 'pvm.conf';
    if (!defined($pvm_conf)) {
        die "error reading $config_file, \$pvm_conf still undefined";
    }

    # If there is a pvm.conf in the users home directory, overlay this on
    # top of the internal one.
    my $home_conf_file = $ENV{HOME} . '/pvm.conf';
    if (-f $home_conf_file) {
        my $saved_pvm_conf = $pvm_conf;
        require $home_conf_file;
        my %new_pvm_conf = (%{$saved_pvm_conf}, %{$pvm_conf});
        $pvm_conf = \%new_pvm_conf;
    }

    $self->{pvm_conf} = $pvm_conf;

    debug('creating hmcs') if (Debug::level() > 1);

    #$self->{hmc_command_runner} = HmcCommandRunner->new();

    #HMC::init($pvm_conf);
    for my $hmc_name (get_hmc_names()) {
        debug('creating hmc ' . $hmc_name) if (Debug::level() > 1);
        my $hmc = Hmc->new($hmc_name, $pvm_conf->{hmc_user});
        #$hmc->set_user($pvm_conf->{hmc_user});
        $self->{hmcs_by_name}{$hmc_name} = $hmc;
    }

    Cache::set_always_valid($pvm_conf->{cache_always_valid});

    return;
}

#-------------------------------------------------------------------------
# Return true if string contains only letters digits or hyphens.
sub _is_ldh_string {
    my $string = shift;
    return $string =~ m/^[a-zA-Z-]+$/;
}
#-------------------------------------------------------------------------
# Return a list of hmc objects.
#
# Optional query string takes the form of comma separated list.
# Each element can either be a pattern or a literal hmc name.
#
# First construct a list of wanted names as follows:
# For each element:
#   If not pattern ("LDH" - letters, digits, hyphen)
#     add literal element to list of wanted names
#   else (is pattern)
#     add matching hmc names to list of wanted names
#
# Then use the list of wanted names to return list of hmc objects:
# For each name on wanted list:
#   If hmc object not already created, create it.
#   Add hmc object to return list.
sub get_hmcs {
    my $hmc_query_string = shift;
    debug('called') if (Debug::level() > 1);

    my $hmcs_by_name_href = $self->{hmcs_by_name};

    return values %{$hmcs_by_name_href} if (!defined($hmc_query_string));

    my @query_elements = split(/,/, $hmc_query_string);
    my %wanted_names_bag;
    for my $query_element (@query_elements) {
        if (_is_ldh_string($query_element)) {
            $wanted_names_bag{$query_element} = undef;
        } else {
          for my $hmc_name (keys %$hmcs_by_name_href) {
              if ($hmc_name =~ m/$query_element/) {
                  $wanted_names_bag{$hmc_name} = undef;
              }
          }
        }
    }
    my @results;
    for my $hmc_name (keys %wanted_names_bag) {
        my $hmc_obj = $hmcs_by_name_href->{$hmc_name};
        if (!defined($hmc_obj)) {
            $hmc_obj = Hmc->new($hmc_name, $pvm_conf->{hmc_user});
            $hmcs_by_name_href->{$hmc_name} = $hmc_obj;
        }
        push @results, $hmc_obj;
    }
    return @results if (@results);
    die "the query string ('$hmc_query_string') did not match or specify any hmcs\n";
}

#-------------------------------------------------------------------------
sub get_hmc_by_name {
  my ($name) = @_;
  return $self->{hmcs_by_name}{$name};
}

#-------------------------------------------------------------------------
sub get_io_slots {
    my $msys = shift;

    if (!defined($msys)) {
        Carp::confess 'no msys supplied';
    }

    my $hmc = $msys->get_hmc();
    my $msys_name = $msys->get_name();

    my $command_conf = Pcmd::get_conf('query lpar io')->{command_conf};

    my ($cache_filename, $cmd, $key) =
        @{$command_conf}{qw/cache_filename cmd key/};

    $cmd =~ s/%MSYS/$msys_name/;
    $cache_filename = "$msys_name/$cache_filename";

    return $hmc->get_cmd_data(
        cache_filename => $cache_filename,
        cmd => $cmd,
        key => $key,
    );
}

#-------------------------------------------------------------------------

sub get_msys_syscfg {
    my $hmc = shift;

    debug('called') if (Debug::level() > 1);
    debug('hmc = ' . $hmc->get_name()) if (Debug::level() > 1);

    if (!defined($hmc)) {
        Carp::confess 'no hmc supplied';
    }

    my $command_conf_href = Pcmd::get_conf('query system list')->{command_conf};
    my $msys_cfg_href = $hmc->get_cmd_data(%{$command_conf_href},);
    return $msys_cfg_href;
}

#-------------------------------------------------------------------------
sub add_io_slot_descriptions {
    my ($attrs_href, $hmc, $msys) = @_;
    debug('called') if (Debug::level() > 1);
    for my $drc_href (values %{$attrs_href}) {
        my $drc_index = $drc_href->{drc_index};
        debug($msys->get_name() . ' ' . $drc_index) if (Debug::level());
        $drc_href->{description} = $msys->get_slot_description($drc_index);
    }
    return;
}

#-------------------------------------------------------------------------

=head1 get_hmc_names( )

Return list of HMC names, as per configuration.

=cut

sub get_hmc_names {
    debug("called") if (Debug::level() > 1);
    if (!defined($self->{pvm_conf}{hmc_names})) {
        Carp::confess
          "{pvm_conf{hmc_names} not defined, has Pvm::init() been called?";
    }
    return @{$self->{pvm_conf}{hmc_names}};
}

#-------------------------------------------------------------------------

=head1 get_lpar_and_msys_from_lpar_spec(lpar-spec)

Returns list of ($msys_name, $lparName) given an lpar-spec string.
The lpar-spec takes the form lparname[@msys_name]. If the lparname
is unique across all HMCs and managed systems (which would seem like a
sensible way for an administrator to set things up!),
the "@msys_name" part of the spec is not needed.

This routine will die if the lpar name is ambiguous, i.e. managed system
name is not specified and the lpar name is not unique across all hmcs and
managed systems.

=cut

sub get_lpar_and_msys_from_lpar_spec {
    my ($lparNameSpec) = @_;

    my ($lparName, $msys_name);

    if ($lparNameSpec =~ m/\//) {

        # managed system name was supplied
        ($lparName, $msys_name) = split('/', $lparNameSpec);
    }
    else {

        # NO managed system name was supplied
        # check lpar not ambiguous -> only one managed system for that lpar

        $lparName = $lparNameSpec;
        my @matching_msys_list;

        # for each hmc...
        for my $hmc (Pvm::get_hmcs()) {
            my $msys_name_href = $hmc->get_cmd_data(
                command_id => "lssyscfg-sys"
            );

            # for each managed system...
            foreach my $msys_name (keys %$msys_name_href) {

                # get lpar names
                my $lpars = $hmc->get_cmd_data(
                    msys       => $msys_name,
                    command_id => "lssyscfg-lpar"
                );
                if (defined($lpars->{$lparName})) {
                    push @matching_msys_list, $msys_name;
                }
            }
        }
        if ($#matching_msys_list != 1) {
            die "lpar $lparName is defined in more than one managed system ("
              . join(",", @matching_msys_list)
              . "), use the syntax lparName/managedSystem to be specific";
        }
        ($msys_name) = @matching_msys_list;
    }
    return ($lparName, $msys_name);
}

#-------------------------------------------------------------------------
sub _count_slashes {
    my ($string) = @_;
    my $count = ($string =~ tr@/@@);
    debug("_count_char_occurances found $count") if (Debug::level());
    return $count;
}

#-------------------------------------------------------------------------
sub lpar_object_path_is_full {
    my ($path) = @_;
    my $is_full = (_count_slashes($path) >= 2);
    debug("lpar_object_path_is_full($path) = $is_full") if (Debug::level());
    return $is_full;
}

#-------------------------------------------------------------------------
sub basename {
    my ($path) = @_;
    if (!defined($path)) {
        Carp::confess "no path supplied";
    }
    my $result = $path;
    $result =~ s@/.*@@;    # greedy
    debug("basename($path) = $result") if (Debug::level());
    return $result;
}

#-------------------------------------------------------------------------
sub dirname {
    my ($path) = @_;
    my $result = $path;
    $result =~ s@.*?/@@;    # not greedy
    debug("dirname($path) = $result") if (Debug::level());
    return $result;
}

#-------------------------------------------------------------------------
sub find_lpar_object {
    my ($lpar_object_spec, $lpar_object_type) = @_;

    my ($command_id, @matching_objects);

    debug("find_lpar_object($lpar_object_spec, $lpar_object_type)")
      if (Debug::level());

    if ($lpar_object_type eq "lpar") {
        $command_id = "lssyscfg-lpar";
    }
    elsif ($lpar_object_type eq "profile") {
        $command_id = "lssyscfg-prof";
    }
    else {
        Carp::confess "invalid lpar_object_type\n";
    }

    my @array = split('/', $lpar_object_spec);
    my $array_length = $#array + 1;
    if ($array_length > 3) {
        die "bad lpar object spec; should take the form a[/b[/c]]\n";
    }
    my ($object_name, $managed_system, $hmc) = @array;

    # loop through all hmcs and managed systems
    # if hmc is defined, only look at matching hmc
    #   if msys defined, only look at matching msys
    #     if object found, add to matching objects
    # error if more than one object found
    # if no object found
    #   check if hmc found
    #     check if msys found

    # for each hmc...
    my $hmc_found;
    my $msys_found;
    debug("finding $object_name") if (Debug::level());
    for my $hmcName (Pvm::get_hmc_names()) {
        next if (defined($hmc) && ($hmc ne $hmcName));
        debug("look in hmc $hmcName") if (Debug::level());
        $hmc_found = 1;
        for my $msys (get_matching_msys_list(hmc => $hmcName)) {
            next if (defined($managed_system) && ($managed_system ne $msys));
            debug("look in msys $msys") if (Debug::level());
            $msys_found = 1;
            my $lpar_objects = $self->{hmc_command_runner}->get_cmd_data(
                hmcName    => $hmcName,
                msys       => $msys,
                command_id => $command_id
            );

            for my $full_object_name (keys %$lpar_objects) {
                my $base_object_name = $full_object_name;
                if ($lpar_object_type eq "profile") {
                    $base_object_name =~ s@:.*@@;
                }
                if ($base_object_name eq $object_name) {
                    push @matching_objects,
                      [ $full_object_name, $msys, $hmcName ];
                }
            }
        }
    }

    if ($#matching_objects > 0) {
        die "lpar $object_name is not unique, it can be found here:\n"
          . join("\n", map { join("/", @$_) } @matching_objects) . "\n";
    }
    else {
        if (!@matching_objects) {
            if (defined($hmc) && !defined($hmc_found)) {
                die "hmc '$hmc' not found\n";
            }
            elsif (defined($managed_system) && !defined($msys_found)) {
                die "managed system '$managed_system' not found";
            }
            else {
                die
"object '$lpar_object_spec' of type '$lpar_object_type' not found\n";
            }
        }
    }
    return @{$matching_objects[0]};

    #return ($object_name, $managed_system, $hmc);
}

#-------------------------------------------------------------------------
sub split_lpar_path {
    my ($path) = @_;
    return split(/\//, $path);
}

#-------------------------------------------------------------------------
sub get_cache_root {
    my $root = $self->{pvm_conf}{hmcCacheRoot};
    if (!defined($root)) {
        die "hmcCacheRoot not defined in config";
    }
    debug("get_cache_root() returning $root") if (Debug::level() > 1);
    return $root;
}

#-------------------------------------------------------------------------

1;

__END__

=head1 AUTHOR

John Buxton
