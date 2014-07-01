#!/bin/perl



=head1 NAME

pparse - Parse CSV output from lpar commands.

=head1 DESCRIPTION

There are multiple standards for CSV formats, but based on what I've seen
so far, the hmc commands produce output which meet the following criteria:

=over

=item 1.
any field containing commas must be surrounded by "

=item 2.
a field must be surrounded by " to contain an embedded "

=item 3.
embedded quotes are represented as a pair of " (i.e. "")

=back

Strings can look like this:
  a=b,"c=d,""e,f,g"",h","i=j,k,l"

Which is just 3 values separated by commas:
  a=b			# first value
  c=d,"e,f,g",h		# second value
  i=j,k,l		# third value

Pseudo-code for the way the values are found in each line of CSV is as follows:

  split line on , into fields
  for each field
    if value not started
      if starts with odd number of "
        strip first "
        value started
      else
        whole value
    else # value started
      if ends with odd number of "
        strip last "
        value end
      else
        continue value


=cut

use warnings;
use strict;
package Pparse;
our ($VERSION) = (q$Revision: 67 $ =~ /(\d+)/msx);

#use Data::Dumper;

#-------------------------------------------------------------------------
=head1 SUBROUTINES

=over 4

=item text_to_hash $text

Process single line of CSV output from an lpar command and convert it
to a hash of key/value pairs. Returns a ref to the resulting hash.

=cut

sub text_to_hash($) {
  my ($line) = @_;
  my %hash = ();

  # If line contains no "=" at all, return undef.
#  if (!($line =~ m/=/)) {
#    return undef;
#  }

  my @fields = split(",", $line);

  my $value;
  foreach (@fields) {

    if (!defined($value)) { # column not started
      $value = $_;
      if (!/^"("")*([^"]|$)/) { # not an odd number of " at start
        goto VALUE_DONE;
      }
      $value =~ s/^"//;    # strip first "
    } else { # value in progress
      $value .= "," . $_;
      if (/([^"]|^)("")*"$/) { # odd number of " at end
	#$value =~ s/"$//;    # strip last "
	chop($value);
        goto VALUE_DONE;
      }
    }
    next;

    VALUE_DONE:
    $value =~ s/("")/"/g; # swap all pairs for singles
    my ($attr, $str) = split("=", $value);
    $hash{$attr} = $str;
    $value = undef;
  }

  #print Dumper(\%hash);
  return \%hash;
}

#-------------------------------------------------------------------------
=item hash_ref_to_text $hashRef

Convert hash back to CSV text. Returns the result as a string.

=cut

sub hash_ref_to_text($) {
  my ($hashRef) = @_;
  my @output;
  foreach my $key (sort keys %$hashRef) {
    my $str = ${$hashRef}{$key};

    my $value;
    if (defined($str)) {
      $str =~ s@"@""@g;
      $value = "$key=$str";
    } else {
      $value = $key;
      $value =~ s@"@""@g;
    }
    if ($value =~ m/,/) {
      $value = "\"$value\"";
    }

    push @output, $value;
  }
  return join(",", @output);
}

1;

=back

=head1 AUTHOR

John Buxton

