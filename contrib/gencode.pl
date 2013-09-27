#!/usr/bin/perl
# Public Domain

# simple script to generate perl code from yt-dl.org python code
#   perl gencode.pl < youtube.py
# or
#  youtube-dl -v \
#	--no-cache-dir \
#	--skip-download \
#	--youtube-print-sig-code http://youtu.be/cmSbXsFE3l8 | \
#  tail -n 3 | perl gencode.pl

use warnings;
use strict;

my $len;
my $found;

while (<STDIN>) {
	if (m/if\s+len.\w+.\s+==\s+(\d+)\:/) {
		$len = $1;
		printf("    \x7d elsif (\@s == %d) \x7b\n", $len);
		next;
	}

	if ($len && m/return\s+(.*)\s*$/) {
		my @items = ();
		for (split(/\s*\+\s*/, $1)) {
			if (m/^\w+\[(\d+)\]$/) {
				push @items, "\$s[$1]";
			} elsif (m/^\w+\[:(\d+)\]$/) {
				my $i = $1 - 1;
				push @items, "\@s[0..$i]";
			} elsif (m/^\w+\[(\d+):(\d+)\]$/) {
				my $i = $2 - 1;
				push @items, "\@s[$1..$i]";
			} elsif (m/^\w+\[(\d+):(\d+):-1\]$/) {
				my $i = $2 + 1;
				push @items, "reverse(\@s[$i..$1])";
			} elsif (m/^\w+\[(\d+)::-1\]$/) {
				push @items, "reverse(\@s[0..$1])";
			} elsif (m/^\w+\[:(\d+)\]\[::-1\]$/) {
				my $i = $1 - 1;
				push @items, "reverse(\@s[0..$i])";
			} elsif (m/^\w+\[(\d+):\]$/) {
				my $i = $len - 1;
				push @items, "\@s[$1..$i]";
			} else {
				die "Unable to parse: $_";
			}
		}
		my $str = join(', ', @items);
		printf("        return (%s);\n", $str);
		$found = 1 if $str;
		undef $len;
		next;
	} elsif ($found && m/ExtractorError/) {
		printf("    \x7d\n");
		last;
	}
}
