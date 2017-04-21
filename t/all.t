#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Email::Footer::Test;

Email::Footer::Test->new({
  dir => 'share',
})->run_all_tests;

done_testing;
