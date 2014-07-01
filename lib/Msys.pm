#!/usr/bin/perl



=head1 NAME

Msys - managed system

Stores lssyscfg data for managed system, plus io slot descriptions
for drc indexes.

=cut

use warnings;
use strict;

package Msys;
our ($VERSION) = (q$Revision: 32 $ =~ /(\d+)/msx);

use Pvm;
use Debug 'debug';

#-------------------------------------------------------------------------------
sub new {
    my ($class, $name, $cfg, $hmc) = @_;
    if (!defined $name) {
        Carp::confess "name not supplied";
    }
    if (!defined $hmc) {
        Carp::confess "hmc not supplied";
    }
    if (!defined $cfg) {
        Carp::confess "cfg not supplied";
    }
    debug("creating msys $name") if (Debug::level() > 1);
    debug("class = $class")      if (Debug::level() > 1);
    my $self = {
        name => $name,
        hmc  => $hmc,
        cfg  => $cfg,
    };
    bless($self, $class);
    return $self;
}

#-------------------------------------------------------------------------------
sub get_name {
    my $self = shift;
    return $self->{name};
}

#-------------------------------------------------------------------------------
sub get_hmc {
    my $self = shift;
    return $self->{hmc};
}

#-------------------------------------------------------------------------------
sub get_slot_description {
    my ($self, $drc_index) = @_;
    if (!defined $self->{io_slots}) {
        $self->{io_slots} = Pvm::get_io_slots($self);
    }
    return $self->{io_slots}{$drc_index}{description};
}
#-------------------------------------------------------------------------------
1;
