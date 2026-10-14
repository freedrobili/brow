#!/usr/bin/perl
# Runs the BrowMediaRemote dylib inside Apple's perl, which is allowed to use MediaRemote.
# Usage: brow-media.pl <path to libBrowMediaRemote.dylib> stream|send
use strict; use warnings; use DynaLoader;
my ($lib, $mode) = @ARGV;
die "usage: brow-media.pl <dylib> stream|send\n" unless $lib && $mode && $mode =~ /^(stream|send)$/;
my $h = DynaLoader::dl_load_file($lib, 0) or die DynaLoader::dl_error();
my $sym = DynaLoader::dl_find_symbol($h, "brow_$mode") or die DynaLoader::dl_error();
DynaLoader::dl_install_xsub("main::run", $sym);
run();
