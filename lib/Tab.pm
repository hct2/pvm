#!/usr/bin/perl



=head1 NAME

tab - tabulate lines of fields in equal width columns

=head1 SUBROUTINES

=cut

use warnings;
use strict;

package Tab;
our ($VERSION) = (q$Revision: 67 $ =~ /(\d+)/msx);

my @justifications;
my ($input_lines_aref, $auto_justify_numbers,
  $justification_specs_aref, $header_line_skip, $underline_char);

#-------------------------------------------------------------------------
# Automatic justification of numeric columns has to be done before
# starting any output, so this is an appropriate place for it.
sub _get_widths() {

  my @field_widths;

  my $line_number = 0;
  for my $line_aref (@$input_lines_aref) {     # for each line
    $line_number++;
    #print "line $line_number\n";
    my $field_index = 0;
    for my $field (@$line_aref) {	# for each field
      if (!defined($field) || $field eq "") {
	$field = "";
      }

      # find field width
      #
      my $len = length($field);
      #print "field=\"$field\", len=$len\n";
      if (
	!defined($field_widths[$field_index]) ||
	$len > $field_widths[$field_index]
      ) {
	$field_widths[$field_index] = $len;
      }

      # handle justifications
      if ($auto_justify_numbers) {

	# only after skipping header rows...
	if ($line_number > $header_line_skip) {

	  # only ever set right justification once for this field,
	  # any non-numeric will set it left and it will stay left.
	  my $current_justification = $justifications[$field_index];
	  if (!defined($current_justification)) {
	    $justifications[$field_index] = "";	# right justify
	    $current_justification = "";
	  }
	  if ($current_justification ne "-") {
	    if (!($field =~ m/^\d+$/)) {	# if not numeric
	      #print "\"$field\" field $i is NOT numeric\n";
	      $justifications[$field_index] = "-";	# left justify
	    }
	  }
	}
      }
      #use Data::Dumper;
      #print "field = $field_index, justifications = " . Dumper(\@justifications);
      $field_index++;
    }
  }
  return \@field_widths;
}


#-------------------------------------------------------------------------

=head1 tabulate(

  input_lines_aref	    => ref to array or arrays (lines of fields)
  justification_specs_aref  => ref to array of column justifications
  auto_justify_numbers	    => boolean
  header_line_skip	    => number of header lines
)

Given a ref to an array of arrays (lines of fields), computes column widths
and returns a B<reference> to a string report with equal width columns
(padded with spaces).
justification_specs_aref and auto_justify_numbers are mutually exclusive

Params are as follows:

=over

=item input_lines_aref

ref to an array of arrays (lines of fields)

=item justification_specs_aref

ref to an array containing column justifications:
  "-" = left justify (default)
  ">" = right justify.

justification_specs_aref and auto_justify_numbers are mutually exclusive

=item auto_justify_numbers

If defined and true, this param causes columns which wholly consist of
digits (numeric) to be right justified.
The is less efficient than the caller specifying the justifications.
justification_specs_aref and auto_justify_numbers are mutually exclusive.
Default is true, if neither justification_specs_aref nor auto_justify_numbers
are defined.

=item header_line_skip

Tells tabulate() how many header rows to expect. This number of rows
will be skipped when searching for numeric columns (see auto_justify_numbers).
Default is 1.

=back

=cut

#use diagnostics;

sub tabulate(%) {
  my (%args) = @_;

  ($input_lines_aref, $auto_justify_numbers,
    $justification_specs_aref, $header_line_skip, $underline_char) =
  @args{qw/input_lines_aref auto_justify_numbers
    justification_specs_aref header_line_skip underline_char/};

  if (defined($auto_justify_numbers) && defined($justification_specs_aref)) {
    die "auto_justify_numbers & justification_specs_aref params " .
    "are mutually exclusive";
  }

  @justifications = ();

  if (!defined($auto_justify_numbers)) {
    # auto_justify_numbers is defaults to true, if neither
    # justification_specs_aref nor auto_justify_numbers are defined by caller
    if (defined($justification_specs_aref)) {
      $auto_justify_numbers = 0;
      # setup justification array, converting:
      # ">" to ""   = right justify
      # "-" to "-"  = left justfiy
      my $field_index = 0;
      foreach my $input_justification (@$justification_specs_aref) {
	if ($input_justification eq ">") {
	  $justifications[$field_index] = "";
	} elsif ($input_justification eq "-") {
	  $justifications[$field_index] = "-";
	} else {
	  die "ERROR: unexpected justfication \"$input_justification\" spec " .
	  "for field $field_index";
	}
	$field_index++;
      }
    } else {
      $auto_justify_numbers = 1;
    }
  }

  if (!defined($header_line_skip)) {
    $header_line_skip = 1;
  }

  if (defined($underline_char)) {
    if (length($underline_char) != 1) {
      die "ERROR: underline char \"$underline_char\" must be a single character";
    }
  }

  # Find max width for each column.
  my $field_widths_aref = _get_widths();

  # Generate output text.
  my $finalOutput = "";
  my $line_number = 0;
  for my $line (@$input_lines_aref) {     # for each line
    $line_number++;
    my $i = 0;
    my $outputLine = "";
    my $underline_needed = ($line_number == $header_line_skip + 1 &&
      defined($underline_char));
    my $underline_string = "";

    for my $field (@$line) {  # for each field
#      $field =~ s/:/,/g;
      my $justify = $justifications[$i];
      my $field_width = $field_widths_aref->[$i];
      my $output_field;
      # ""  = right justify (empty string)
      # "-" = left
      #print "field = \"$field\", format = \"%${justify}*s\", width=" . $field_widthss->[$i] . "\n";
      #if (!defined($justify)) {
      #Carp::confess "ERROR: justify not defined\n";
      #}
      $output_field = sprintf("%${justify}*s", $field_width, $field);
      if ($underline_needed) {
        $underline_string .= ($underline_char x $field_width) . " ";
      }
      $outputLine .= "$output_field ";
      $i++;
    }

    if ($underline_needed) {
      $finalOutput .= "$underline_string\n";
    }
    $finalOutput .= "$outputLine\n";
  }
  return \$finalOutput;
}
#-------------------------------------------------------------------------

1;

__END__

=head1 AUTHOR

John Buxton
