#!/usr/bin/perl -w

use strict;
use vars qw($opt_v $opt_w $opt_s $opt_p);

use Getopt::Std;
use Text::Lorem;

getopts("vw:s:p:");

if ($opt_v) {
    print usage();
    exit 0;
}

die usage()
    if ((defined($opt_w) + defined($opt_s) + defined($opt_p)) > 1);

my $lorem = Text::Lorem->new;
if ($opt_w) {
    print $lorem->words($opt_w);
    print "\n";
}
elsif ($opt_s) {
    print $lorem->sentences($opt_s);
    print "\n";
}
elsif ($opt_p) {
    print $lorem->paragraphs($opt_p);
    print "\n";
}
else {
    print $lorem->paragraphs(1);
    print "\n";
}

sub usage {
    return <<USAGE;
$0 - Generate random Latin looking text using Text::Lorem

Usage:
    $0 -w NUMBER_OF_WORDS
    $0 -s NUMBER_OF_SENTENSES
    $0 -p NUMBER_OF_PARAGRAPHS

-w, -s, and -p are mutually exclusive.
USAGE
}

__END__

=head1 NAME

lorem - Generate random Latin looking text using Text::Lorem

=head1 SYNOPSIS

Generate 3 paragraphs of Latin looking text:

    $ lorem -p 3

Generate 5 Latin looking words:

    $ lorem -w 5

Generate a Latin looking sentence:

    $ lorem -s 1

=head1 DESCRIPTION

F<lorem> is a simple command-line wrapper around the C<Text::Lorem>
module.  It provides the same three basic methods:  Generate C<words>,
generate C<sentences>, and generate C<paragraphs>.


