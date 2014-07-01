#! /usr/bin/perl



use warnings;
use strict;

our ($VERSION) = (q$Revision: -1 $ =~ /(\d+)/msx);

package Hmc;

use base 'Hmc::CommandRunner';
use Pvm;
use Msys;
use Debug qw/debug/;

#-------------------------------------------------------------------------------
sub _get_msys_cfg_data {
    my $self = shift;

    debug('called') if (Debug::level() > 1);
    my $msys_cfg_by_name_href = Pvm::get_msys_syscfg($self);

    for my $msys_name (keys %{$msys_cfg_by_name_href}) {
        my $msys_cfg = $msys_cfg_by_name_href->{$msys_name};
        my $msys = Msys->new($msys_name, $msys_cfg, $self);
        $self->{msys_by_name}{$msys_name} = $msys;
    }
    return;
}
#-------------------------------------------------------------------------------
sub get_msys_list {
    my $self = shift;
    debug('called') if (Debug::level() > 1);
    if (!defined $self->{msys_by_name}) {
        $self->_get_msys_cfg_data();
    }
    return values %{$self->{msys_by_name}};
}
#-------------------------------------------------------------------------------
sub get_msys {
    my ($self, $msys_name) = @_;
    debug('called') if (Debug::level());
    if (!defined $self->{msys_by_name}) {
        $self->_get_msys_cfg_data();
    }
    return $self->{msys_by_name}{$msys_name};
}
#-------------------------------------------------------------------------------
sub get_version { #TODO
    debug('called') if (Debug::level());
    my $self = shift;
    if (!exists($self->{lshmc})) {
        $self->{lshmc} = Cache::get_cmd_data(
            cache_filename => 'lshmc',
            cmd => 'lshmc -v',
            user_process_fn => \&_parse_lshmc,
        );
    }
    return $self->{lshmc}{version};
}
#-------------------------------------------------------------------------------
sub _parse_lshmc {
    die "not implemented yet";
}
#-------------------------------------------------------------------------------

1;

