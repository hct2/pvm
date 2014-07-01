#! /usr/bin/perl
#      $URL: https://subversion.assembla.com/svn/pvm/trunk/lib/HMC.pm $
#     $Date: 2011-05-23 13:50:17 +0100 (Mon, 23 May 2011) $
#   $Author: lqueryvg $
# $Revision: 30 $
#
# Copyright 2011 by John Buxton, HCT Solutions Ltd, UK, All rights reserved.
# See LICENSE.txt distributed with this software for license and warranty info.


use warnings;
use strict;

package Drc;
our ($VERSION) = (q$Revision: 30 $ =~ /(\d+)/msx);
use Debug 'debug';

my $drc_attributes = {
    io_slots => {
        attribute_list => [
            qw/
              drc_index
              slot_io_pool_id
              is_required
              /
        ],
        primary_key => 'drc_index'
    },
    virtual_fc_adapters => {
        attribute_list => [
            qw/
              slot_num
              adapter_type
              remote_lpar_id
              remote_lpar_name
              remote_slot_num
              wwpns
              is_required
              /
        ],
        primary_key => 'slot_num'
    },
    virtual_eth_adapters => {
        attribute_list => [
            qw/
              slot_num
              ieee_virtual_eth
              port_vlan_id
              addl_vlan_ids
              trunk_priority
              is_required
              vswitch
              mac_addr
              allowed_os_mac_addresses
              qos_priority
              /
        ],
        primary_key => 'slot_num'
    },
    virtual_scsi_adapters => {
        attribute_list => [
            qw/
              slot_num
              adapter_type
              remote_lpar_id
              remote_lpar_name
              remote_slot_num
              is_required
              /
        ],
        primary_key => 'slot_num'
    },
    virtual_serial_adapters => {
        attribute_list => [
            qw/
              slot_num
              adapter_type
              supports_hmc
              remote_lpar_id
              remote_lpar_name
              remote_slot_num
              is_required
              /
        ],
        primary_key => 'slot_num'
    }
};

#-------------------------------------------------------------------------------
sub _get_drc_attributes_aref {
    my ($attribute_name) = @_;
    return $drc_attributes->{$attribute_name}{attribute_list};
}

#-------------------------------------------------------------------------
sub _get_drc_primary_key_name {
    my ($attribute_name) = @_;
    return $drc_attributes->{$attribute_name}{primary_key};
}

#-------------------------------------------------------------------------
# convert csv drc list to hash indexed by primary key (e.g. slot number)
sub _expand_single_drc {
    my ($str, $attribute_name) = @_;
    my $href = Pparse::text_to_hash($str);
    my %result;

    # each key is a drc_name string
    for my $drc (keys %{$href}) {
        debug("drc = $drc") if (Debug::level());
        next if ($drc eq "none");
        my @arr = split("/", $drc);
        my %subhash;
        my $sub_attributes_aref = _get_drc_attributes_aref($attribute_name);
        for (my $i = 0 ; $i <= $#{$sub_attributes_aref} ; $i++) {
            my $subitem_name = ${$sub_attributes_aref}[$i];
            debug("subitem_name = $subitem_name") if (Debug::level());
            my $subitem_value = $arr[$i];
            if (!defined $subitem_value || $subitem_value eq "") {
                $subitem_value = "-"
	    }
            debug("subitem_value = $subitem_value") if (Debug::level());
            $subhash{$subitem_name} = $subitem_value;
        }
        my $primary_key_name = _get_drc_primary_key_name($attribute_name);
        debug("primary_key_name = $primary_key_name") if (Debug::level());
        my $primary_key_value = $subhash{$primary_key_name};
        $result{$primary_key_value} = \%subhash;
    }
    return \%result;
}

#-------------------------------------------------------------------------
sub convert_drc_hash_to_csv {
    my ($href, $attribute_name) = @_;
    debug('called')         if (Debug::level() > 1);
    debug("attribute_name = $attribute_name") if (Debug::level() > 1);
    my $sub_attributes_aref = _get_drc_attributes_aref($attribute_name);

    my @result_list;
    my @drc_keys = keys %$href;
    return "none" if (!@drc_keys);    # empty hash = no drc values

    for my $sub_hash (values %$href) {
        my @sub_list;
        for (my $i = 0 ; $i <= $#{$sub_attributes_aref} ; $i++) {
            my $subitem_name  = ${$sub_attributes_aref}[$i];
	    debug("subitem_name = $subitem_name") if (Debug::level() > 8);
            my $subitem_value = $sub_hash->{$subitem_name};
	    #next if (!defined($subitem_value));
	    if (!defined($subitem_value)) {
	      $subitem_value = "-";
	    };
	    debug("subitem_value = $subitem_value") if (Debug::level() > 8);

            #if (!defined($subitem_value) || $subitem_value eq "-") {
            if ($subitem_value eq "-") {
                $subitem_value = "";
            }
            push @sub_list, $subitem_value;
        }
        my $sub_str = join("/", @sub_list);
        $sub_str = "\"$sub_str\"" if ($sub_str =~ m/\,/);
        push @result_list, $sub_str;
    }
    return join(",", @result_list);
}

#-------------------------------------------------------------------------
# Convert any drc attributes into hashes as follows:
# For every key in hash, if key is a drc attribute and if it contains a
# string, convert the string value (which is drc list) into a nested
# hash.
sub expand_all_drcs {
    my (%args) = @_;
    my ($href, $add_drc_descriptions, $msys) =
      @args{qw/profile_href add_drc_descriptions msys/};

    #my ($href) = @_;
    for my $attribute_name (keys %$href) {
        next if (!exists($drc_attributes->{$attribute_name}));

        debug("found drc attribute $attribute_name") if (Debug::level());
        my $drc_string = $href->{$attribute_name};
        debug("value = $drc_string") if (Debug::level());
        my $sub_hash = _expand_single_drc($drc_string, $attribute_name);

        $href->{$attribute_name} = $sub_hash;
    }
    return;
}

#-------------------------------------------------------------------------
sub flatten_drc_hashes {
    my ($href) = @_;
    for my $attr (keys %{$href}) {
        my $value = $href->{$attr};

        # check if drc attribute
        if (ref($value)) {
	    debug("attr = $attr") if (Debug::level()> 8);
            $value = convert_drc_hash_to_csv($value, $attr);
            debug("flattened value = $value") if (Debug::level());
            $href->{$attr} = $value;
        }
    }
    return;
}

#-------------------------------------------------------------------------
sub get_sub_attribute_data {
    my ($cmd_data, $attr_name) = @_;

    debug("get_sub_attribute_data()") if (Debug::level());
    debug("attr_name = $attr_name")                if (Debug::level());
    my $primary_key_name = _get_drc_primary_key_name($attr_name);
    debug("primary_key_name = $primary_key_name") if (Debug::level());

    my %result;
    for my $profile_name (keys %{$cmd_data}) {
        debug("profile_name = $profile_name") if (Debug::level());
        my $drc_list_csv = $cmd_data->{$profile_name}{$attr_name};

        $drc_list_csv = q{} if (!defined($drc_list_csv));
        debug("drc_list_csv = $drc_list_csv") if (Debug::level());

        my $drc_href = _expand_single_drc($drc_list_csv, $attr_name);

        # Now fix the keys of the result hash and point it's values
        # at the hashes within the sub hash.
        # Also, if these are io_slots, add in the descriptions.
        for my $key (keys %{$drc_href}) {
	    my $outer_key = "$profile_name/$key";
            debug("outer_key = $outer_key") if (Debug::level());

            # At this point the profile name is of the form profile/lpar.
	    # Split it and add name and lpar_name attrs to the hash for
	    # reporting purposes.
            my ($base_profile_name, $lpar_name) = split("/", $profile_name);
	    @{$drc_href->{$key}}{qw/name lpar_name/} =
	        ($base_profile_name, $lpar_name);

            $result{$outer_key}          = \%{$drc_href->{$key}};
        }

        # can forget the sub hash since the result hash now has references to
        # all of the inner hashes
    }
    return \%result;
}
#-------------------------------------------------------------------------

1;
