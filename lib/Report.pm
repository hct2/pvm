#!/usr/bin/perl



use warnings;
use strict;

=head1 NAME

report - generate tabulated textual report

=head1 SUBROUTINES

=cut

package Report;
our ($VERSION) = (q$Revision: 67 $ =~ /(\d+)/msx);

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Tab;
use Carp qw(confess);
use Debug 'debug';

my @lines;
my @attrs;

#my @headings;
my $current_line_ref;
my $abbreviations_ref;

#-------------------------------------------------------------------------

=head2 set_abbreviations(

    abbreviations_ref => ref to hash of abbreviations
  )

Assign abbreviations to attributes.
The hash is keyed by attribute name and each value is a ref to a hash of string
translations. For example:
  attribute1 => {
    one => 1
    two => 2
  },
  attribute2 => {
    "Universal Serial Bus" => "USB"
    "Fibre Channel" => "FC"
  }

In the above example, all occurances of "one" will be replaced by "1"
when appearing in the "attribute1" attribute, and all occurances of
"Fibre Channel" will be replaced by "FC" in the "attribute2" attribute.
The string to be replaced is treated as a regular expression.

=cut

sub set_abbreviations {
    my (%args)               = @_;
    my ($_abbreviations_ref) = @args{qw/abbreviations_ref/};

    if (!defined($_abbreviations_ref)) {
        Carp::confess "abbreviations_ref param required";
    }
    $abbreviations_ref = $_abbreviations_ref;
}

#-------------------------------------------------------------------------

=head2 init_from_template(

    template_string_ref => ref to template string
  )

Initialises a fresh report.  Any previous report information will be discarded.
template_string_ref is a ref to a string contain the config for the report.
The config string contains one line for each column to be included in the
report, and consists of the following fields:

  source_field     heading    sort  justify  sort_fn

Lines may be blank or contain comments beginning with a # char.
Variable amounts of whitespace are allowed, so that calling code can be made
to look readable if desired.

Only source_field and heading are required fields. The others may be omitted
in which case they take the default value of "-" (see below for meaning).

The fields have the following meanings:

=over

=item source_field

"-" denotes this is a custom column; the caller is expected to pass
custom column values as an array with each line added to report,
these will be placed in the list of output fields in the order specified by
the report template.

If the source field is not "-", then it should specify the corresponding
attribute to be extracted from the attrs_href hash passed
to add_line() for each line of the report.

=item heading

The heading to be used for the column.

=item sort

"-" denotes no particular sort order for the column. Otherwise, a number
specifies where the column should factor sorting of the final output.
There may be gaps between the sort order numbers, but two columns are not
allowed the same number.

=item justify

"-" = left justify. ">" = right justify.

=item sort_fn

Specifies a special sort function to be used for this column. Blank or "-"
means default string comparison (implemented by perl cmp operator). "n" performs
a numeric comparison.
Other values might be supported in the future. TODO

=back


=cut

my (
    @column_source_fields_arr, @justification_specs_arr,
    @column_headings_arr,      @sort_column_indices,
    @sort_fns,                 %sort_column_index_by_sort_number,
    $expected_custom_column_count
);

sub init_from_template {
    my (%args)                = @_;
    my ($template_string_ref) = @args{qw/template_string_ref/};

    debug('called') if (Debug::level() > 9);
    @column_source_fields_arr = @justification_specs_arr =
      @column_headings_arr = @sort_column_indices = @sort_fns = ();
    %sort_column_index_by_sort_number = ();
    $expected_custom_column_count     = 0;

    if (!defined($template_string_ref)) {
        Carp::confess "template_string_ref param required";
    }

    if (!defined(${$template_string_ref})) {
        Carp::confess "template_string_ref must point to something";
    }
    @lines = ();
    my @template_lines = split("\n", ${$template_string_ref});
    #Carp::confess;

    my $column_index = 0;
    for my $line (@template_lines) {

        $line =~ s/#.*$//;    # delete comments
        next if ($line =~ m/^\s*$/);    # skip empty lines
        $line =~ s/^\s*//;              # strip leading space

        my @fields = split(/\s+/, $line);
        my $number_of_fields_found = $#fields + 1;
        if ($number_of_fields_found < 2) {
            Carp::confess "expect at least 2 fields in report template, found "
              . "$number_of_fields_found, template line is:\n<$line>\n";
        }
        my $extra_fields_needed = 5 - $number_of_fields_found;
        while ($extra_fields_needed > 0) {
            push @fields, "-";
            $extra_fields_needed--;
        }

        my ($source_field, $heading, $sort, $justify, $sort_fn) = @fields;
        if (!defined($sort_fn)) {
            $sort_fn = "-";
        }
        push @sort_fns, $sort_fn;

        if ($source_field eq "-") {
            $expected_custom_column_count++;
        }

        push @column_source_fields_arr, $source_field;
        push @justification_specs_arr,  $justify;

        if ($sort ne "-") {

            # Build up a hash of column indexes, keyed by sort order number.
            # (Duplicate sort order numbers are not allowed.)
            # This will be used to work out the order to sort the columns.
            if (defined($sort_column_index_by_sort_number{$sort})) {
                Carp::confess "duplicate sort number \"$sort\" found, "
                  . "template line is:\n<$line>\n";
            }
            $sort_column_index_by_sort_number{$sort} = $column_index;
        }

        # headings will be added after final sort
        push @column_headings_arr, $heading;
        $column_index++;
    }

    #use Data::Dumper;
    #print Dumper(\@column_source_fields_arr, \@column_headings_arr);

    # Create array of column indexes specifying the sort order.
    # order of the array
    foreach my $sort_number (sort keys %sort_column_index_by_sort_number) {
        push @sort_column_indices,
          $sort_column_index_by_sort_number{$sort_number};
    }

    #use Data::Dumper;
    #print Dumper(\%sort_column_index_by_sort_number, \@sort_column_indices);
    # TODO:
    # Lookup table of sort funcs indexed by regular expressions is used to
    # choose special sort funcs for matching columns headings.
    # Eg. a column whose heading matches the string "MAC" might use a sort func
    # which knows how to sort MAC addresses.
}

#-------------------------------------------------------------------------
sub get_headings_help {
    my ($template_string_ref) = @_;
    if (!defined($template_string_ref)) {
        Carp::confess "ERROR: template_string_ref not suppled\n";
    }
    init_from_template(template_string_ref => $template_string_ref);

    my @lines;

    push @lines, [ "Heading", "Source-field" ];
    push @lines, [ "=======", "============" ];
    for (my $i = 1 ; $i <= $#column_headings_arr ; $i++) {
        my $column_heading = $column_headings_arr[$i];
        my $source_field   = $column_source_fields_arr[$i];
        if ($column_heading eq "Msys") {
            $source_field = "Managed System";
        }

        #print "  $column_heading = $source_field\n";
        push @lines, [ $column_heading, $source_field ];
    }
    return ${Tab::tabulate(input_lines_aref => \@lines, header_line_skip => 2)};
}

#-------------------------------------------------------------------------

=head2 add_line(

    custom_fields_aref => ref to array of custom field values
    attrs_href         => ref to hash or attribute/values
  )

Add a line to the report.

=over

=item custom_fields_aref

Ref to an array of custom field values. These will be inserted into the
report columns in the order that the custom columns were specified in
the report template.

=item attrs_href

Ref to a hash of attribute values. The attributes specified in the report
template will be extracted from this hash and placed in the field positions
specified by the template.

=back

=cut

sub add_line {
    my (%args) = @_;
    my ($custom_fields_aref, $attrs_href) =
      @args{qw/custom_fields_aref attrs_href/};    # slice

    debug('called') if (Debug::level() > 9);
    my $custom_field_count = 0;
    if (defined($custom_fields_aref)) {
        $custom_field_count = $#{$custom_fields_aref} + 1;
    }
    if (!defined($expected_custom_column_count)) {
        Carp::confess "ERROR: \$expected_custom_column_count not defined\n"
          . "*** MAYBE the report has not been initialised ? ****\n";
    }
    if ($custom_field_count != $expected_custom_column_count) {
        Carp::confess "expected $expected_custom_column_count custom columns, "
          . "but got $custom_field_count";
    }

    _start_new_line();

    # for each field in report template
    my $column_index        = 0;
    my $custom_column_index = 0;
    foreach my $source_field (@column_source_fields_arr) {
        my $field_value;
        if ($source_field ne "-") {    # if source_field not custom
                                       # take from attrs_href
            $field_value = $$attrs_href{$source_field};

            # apply abbreviation if found
            if (defined($abbreviations_ref)) {

                #print "looking for abbreviations\n";
                my $translations_href = $$abbreviations_ref{$source_field};
                if (defined($translations_href)) {

                    # TODO
                    foreach my $regexp (keys %$translations_href) {
                        if ($field_value =~ $regexp) {
                            my $substitution = $$translations_href{$regexp};
                            $field_value =~ s/$regexp/$substitution/;
                            goto ABBREVIATION_FOUND;
                        }
                    }
                }
            }
          ABBREVIATION_FOUND:
        }
        else {

            # take from custom_fields_aref
            $field_value = $$custom_fields_aref[$custom_column_index];
            $custom_column_index++;
        }
        if (!defined($field_value)) {
            debug('field_value not defined') if (Debug::level() > 9);
            $field_value = "-";
        }
        push @$current_line_ref, $field_value;
        $column_index++;
    }
}

#-------------------------------------------------------------------------
sub _start_new_line {
    $current_line_ref = [];
    push @lines, $current_line_ref;
}

#-------------------------------------------------------------------------

=head2 get_text_ref

Return final report text.

=cut

sub get_text_ref {

    my @result_lines;

    push @result_lines, \@column_headings_arr;

    if (@sort_column_indices) {

        push @result_lines, sort {
            foreach my $column_index (@sort_column_indices)
            {
                my $comparison_result;
                my $sort_fn = $sort_fns[$column_index];
                if ($sort_fn eq "n") {
                    $comparison_result =
                      $a->[$column_index] <=> $b->[$column_index];
                }
                elsif ($sort_fn eq "-") {

                    #print "column_index = $column_index\n";
                    $comparison_result =
                      $a->[$column_index] cmp $b->[$column_index];
                }
                else {

                    # TODO implement custom sort functions
                    Carp::confess
"comparison functions in field 5 of report not implemented yet";
                }
                return $comparison_result if $comparison_result;

             # otherwise, rows are equal based on this column, so loop continues
             # to compare next column in sort order
            }
        } @lines;
    }
    else {
        push @result_lines, @lines;
    }

    #use Data::Dumper;
    #print Dumper \@result_lines;
    return Tab::tabulate(
        input_lines_aref         => \@result_lines,
        justification_specs_aref => \@justification_specs_arr,
        underline_char           => "="
    );
}

#-------------------------------------------------------------------------

1;

__END__

=head1 AUTHOR

John Buxton
