#!/usr/bin/perl


use warnings;
use strict;

package Cli;

use Utils;
use Carp;

our ($VERSION) = (q$Revision: 74 $ =~ /(\d+)/msx);

my $program_name = $0;
$program_name =~ s@.*/@@x;    # basename
my $SPACE = q{ };

#----------------------------------------------------------------------------
# Chicken and Egg.
# If we want to debug this module, we can't use the command line debug option
# because we haven't parsed the command line yet ! Have to uncomment these two
# lines instead.
#use Debug 'debug';
#Debug::set_level(9);
#----------------------------------------------------------------------------
# GLOBALS, yuk!
my $commands;
my %candidate_base_commands;
my $num_base_command_candidates;
my $num_args;
my $process_optional_args;
my $process_mandatory_args;
my $all_mandatory_args_processed;
my $num_mandatory_args;
my $command;
my $mandatory_args_aref;
my $base_command_aref;
my $mandatory_arg_i;
my %attributes;
my @expanded_command;
my $argc;
my %optional_args;
my $optional_args_aref;

#----------------------------------------------------------------------------
sub _init {
    my ($pcmd_conf) = @_;
    my %commands;
    for my $cmd (keys %{$pcmd_conf}) {
        my $usage = $pcmd_conf->{$cmd}{usage};
        if (defined($usage)) {
            my @base_command = split(/ /, $cmd);
            $commands{$cmd} = $usage;
            $usage->{base_command} = \@base_command;
        }
        else {
            croak "no usage for command \"$cmd\"";
        }
    }
    $commands                     = \%commands;
    %candidate_base_commands      = map { $_ => undef } keys %$commands;
    $num_base_command_candidates  = scalar keys %candidate_base_commands;
    $num_args                     = scalar @ARGV;
    $process_optional_args        = 0;
    $process_mandatory_args       = 0;
    $all_mandatory_args_processed = 0;
    return;
}

#----------------------------------------------------------------------------
# Create text to be fed back to the user.
#
sub _get_candidate_base_commands {
    my (%args) = @_;

    if (!exists($args{without_optional_args})) {
        $args{without_optional_args} = 0;
    }

    use Data::Dumper;

    #print Dumper \$commands;
    my @candidates = map {

        my @converted_mandatory_args = map {
            my ($a, $v) = split("=", $_);
            "[$a=]$v";
        } @{$commands->{$_}{mandatory_args}};

        my @list =
          (@{$commands->{$_}{base_command}}, @converted_mandatory_args);

        if ($args{without_optional_args} == 0) {
            my $optional_args = join('] [', @{$commands->{$_}{optional_args}});
            if ($optional_args) {
                $optional_args = "[$optional_args]";
            }
            push @list, $optional_args;
        }

        join(' ', @list);
    } keys %candidate_base_commands;
    my @sorted_commands = sort @candidates;
    return '  ' . join("\n  ", @sorted_commands) . "\n";
}

#----------------------------------------------------------------------------

sub _long_usage {
    return <<"EOF_USAGE";
Usage: $program_name <command>

Commands can be abbreviated as long as they are unique.
Eg. "$program_name query cpu profile" becomes "$program_name q c p".

If more than one command is matched, matching commands are listed.
Explore the interface. Eg.
  $program_name      # list all commands
  $program_name q    # list all commands beginning with "q"

Once enough arguments have been specified to uniquely identify
a command, add -?, -h or -help to view help for that command.
E.g.
  pvm q c p -?		# show help for "query cpu profile" command

Possible commands are as follows:
EOF_USAGE
}

#----------------------------------------------------------------------------
sub _get_offending_arg_string {
    my ($bad_argc) = @_;
    my $argc_i = -1;
    return "  $program_name " . join(
        " ",
        map {
            $argc_i++;
            if ($argc_i == $bad_argc) {
                ">>>$_<<<";
            }
            else {
                $_;
            }
          } @ARGV
    ) . "\n";
}

#----------------------------------------------------------------------------
sub _get_offending_arg_text {
    my ($bad_argc) = @_;
    print _get_offending_arg_string($bad_argc);
    print "Usage:\n" . _get_candidate_base_commands();
    print "Current expanded command:\n  "
      . join(" ", @expanded_command) . ")\n";
    return;
}

#----------------------------------------------------------------------------
sub _set_attribute {
    my ($attribute, $value) = @_;
    if (defined($attributes{$attribute})) {
        print "ERROR: attribute $attribute defined more than once\n";
        _get_offending_arg_text($argc);
        exit 1;
    }
    $attributes{$attribute} = $value;
    return;
}

#----------------------------------------------------------------------------
sub _start_processing_optional_args {
    $process_optional_args = 1;
    $optional_args_aref    = $commands->{$command}{optional_args};
    for my $opt (@$optional_args_aref) {
        my ($attr, $val) = split("=", $opt);
        $optional_args{$attr} = $val;
    }
    return;
}

#----------------------------------------------------------------------------
sub attr_equals {
    my ($attrs_ref, $attr, $val) = @_;
    return
      defined(($attrs_ref->{options}{$attr})
          && $attrs_ref->{options}{$attr} eq $val);
}

#----------------------------------------------------------------------------
sub _show_help_and_exit {
    if ($num_base_command_candidates == 1) {
        print "Usage:\n" . _get_candidate_base_commands();
    }
    else {
        print _long_usage()
            . _get_candidate_base_commands(without_optional_args => 1);
    }
    exit 0;
}
#----------------------------------------------------------------------------

sub get_cli_options {
    my ($pcmd_conf) = @_;

    _init($pcmd_conf);

    for ($argc = 0 ; $argc <= $#ARGV ; $argc++) {

        my $arg = $ARGV[$argc];

        if ($arg eq '-?' || $arg eq '-h' || $arg eq '-help') {
	    _show_help_and_exit();
        }

        if (Debug::level()) {
            debug('arg = ' . $arg);
            debug('process_mandatory_args = ' . $process_mandatory_args);
            debug('process_optional_args = ' . $process_optional_args);
            debug(
                'num_base_command_candidates =' . $num_base_command_candidates);
        }

        if ($process_optional_args) {

            #-------------------------------------------
            # Optional args
            #-------------------------------------------
            my ($actual_attribute, $actual_value) = split(/=/msx, $arg);
            if (!defined($actual_value)) {
                print "ERROR: optional arg does not contain an \"=\"\n";
                _get_offending_arg_text($argc);
                exit 1;
            }

            # check that attribute matches only one optional arg attr
            my $full_attribute;
            for my $key (keys %optional_args) {

                #print "check $key $actual_attribute\n";
                if ($key =~ /^$actual_attribute/msx) {
                    if (defined($full_attribute)) {
                        print
"ERROR: \"$actual_attribute\" matches more than one optional "
                          . "arg (\"$full_attribute\" and \"$key\", at least)\n";
                        _get_offending_arg_text($argc);
                        exit 1;
                    }
                    else {
                        $full_attribute = $key;
                    }
                }
            }
            if (!defined($full_attribute)) {
                print
"usage error: \"$actual_attribute\" does not match any optional "
                  . "argument names\n";
                _get_offending_arg_text($argc);
                exit 1;
            }

            my $expected_value = $optional_args{$full_attribute};
            my @allowed_values = split("\\|", $expected_value);
            if (scalar @allowed_values == 1) {
                _set_attribute($full_attribute, $actual_value);
                push @expanded_command, "$full_attribute=$actual_value";
            }
            else {
                my $matched_value;
                for my $allowed_value (@allowed_values) {
                    if ($allowed_value =~ /^$actual_value/msx) {
                        if (defined($matched_value)) {
                            print
"ERROR: value \"$actual_value\" matches more than "
                              . "possible value for option \"$full_attribute\".\n";
                            print "Matches at least \"$matched_value\" and "
                              . "\"$allowed_value\".\n";
                            _get_offending_arg_text($argc);
                            exit 1;
                        }
                        else {
                            $matched_value = $allowed_value;
                        }
                    }
                }
                if (!defined($matched_value)) {
                    print "ERROR: value \"$actual_value\" does not match any "
                      . "valid values for option \"$full_attribute\"\n";
                    _get_offending_arg_text($argc);
                    exit 1;
                }
                _set_attribute($full_attribute, $matched_value);
                push @expanded_command, "$full_attribute=$matched_value";
            }
        }
        elsif ($process_mandatory_args) {

            #-------------------------------------------
            # Mandatory args
            #-------------------------------------------
            my $expected_arg = $mandatory_args_aref->[$mandatory_arg_i];
            my ($expected_attribute, $expected_value) =
              split(/=/msx, $expected_arg);
            my ($actual_attribute, $actual_value) = split(/=/msx, $arg);

            my $value;
            my $attribute = $expected_attribute;
            if (!defined($actual_value)) {
                $value = $actual_attribute;
            }
            else {
                if (!($expected_attribute =~ /^$actual_attribute/msx)) {
                    print "ERROR: \"$expected_arg\" expected\n";
                    _get_offending_arg_text($argc);
                    exit 1;
                }
                else {
                    $value = $actual_value;
                }
            }
            _set_attribute($attribute, $value);
            push @expanded_command, "$attribute=$value";

            $mandatory_arg_i++;
            if ($mandatory_arg_i > ($num_mandatory_args - 1)) {

                # all mandatory args processed
                $all_mandatory_args_processed = 1;
                $process_mandatory_args       = 0;
                _start_processing_optional_args();
            }
        }
        elsif ($num_base_command_candidates > 1) {

            #-------------------------------------------
            # Base command
            #-------------------------------------------
            my $regex = $arg;
            eval { q{} =~ /$regex/msx };    # check it won't cause runtime error
            if ($@) {
                print
                  "ERROR: cli arg '$regex' is not a valid regular expression\n";
                print "full perl error text is '$@'\n";
                exit 1;
            }

            # now see if it matches any commands and reduce candidates
            for my $candidate_key (keys %candidate_base_commands) {

                my $candidate_command_aref =
                  $commands->{$candidate_key}{base_command};
                my $candidate_arg =
                  $commands->{$candidate_key}{base_command}[$argc];

                next if ($candidate_arg =~ /^$regex/msx);

                debug("delete candidate \"$candidate_arg\"")
                  if (Debug::level());
                delete $candidate_base_commands{$candidate_key};
                $num_base_command_candidates =
                  scalar keys %candidate_base_commands;
                debug('num_base_command_candidates = '
                      . $num_base_command_candidates)
                  if (Debug::level());

            }    # end for each candidate
            if ($num_base_command_candidates == 1) {

                # Command is unique.
                # Check that the internal base command array has been
                # exhausted. If not, throw an internal error.

                ($command) = (keys %candidate_base_commands);
                $base_command_aref = $commands->{$command}{base_command};
                push @expanded_command, @{$base_command_aref};

                # need to process any remaining command argument specifiers
                my $num_command_args = scalar @{$base_command_aref};
                my $num_args_used    = $argc + 1;

                if ($num_args_used < $num_command_args) {
                    croak 'Internal error, '
                      . "too many base_command args for command \"$command\"\n"
                      . "  config needs to use fewer words\n ";
                }

                if (exists($commands->{$command}{mandatory_args})) {
                    $mandatory_args_aref =
                      $commands->{$command}{mandatory_args};
                    $num_mandatory_args = scalar @{$mandatory_args_aref};
                }
                else {
                    $num_mandatory_args = 0;
                }

                if ($num_mandatory_args > 0) {
                    $mandatory_arg_i        = 0;
                    $process_mandatory_args = 1;
                }
                else {
                    $all_mandatory_args_processed = 1;

                    #$process_optional_args = 1;
                    _start_processing_optional_args();
                }
            }
        }
        else {
            print "ERROR: no matching command\n";
            print _get_offending_arg_string($argc);
            exit 1;
        }
    }

    if ($num_base_command_candidates == 0) {
        print "ERROR: no matching commands\n";
        exit 1;
    }
    elsif ($num_base_command_candidates > 1) {

        #print "# " . join(" ", @expanded_command) . "\n";
        print "Possible commands:\n"
          . _get_candidate_base_commands(without_optional_args => 1);
        exit 1;
    }

    if (!$all_mandatory_args_processed) {
        print 'ERROR: missing arg "'
          . $mandatory_args_aref->[$mandatory_arg_i] . "\"\n"
          . _get_candidate_base_commands();
        exit 1;
    }

    print '# ' . join($SPACE, @expanded_command) . "\n";

    my $ret = {
        command          => $command,
        options          => \%attributes,
        expanded_command => \@expanded_command
    };

    return $ret;
}

1;
