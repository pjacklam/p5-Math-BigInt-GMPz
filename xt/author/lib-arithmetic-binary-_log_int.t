# -*- mode: perl; -*-

use strict;
use warnings;

use Test::More tests => 27369;

###############################################################################
# Read and load configuration file and backend library.

use Config::Tiny ();

my $config_file = 'xt/author/lib.ini';
my $config = Config::Tiny -> read('xt/author/lib.ini')
  or die Config::Tiny -> errstr();

# Read the library to test.

our $LIB = $config->{_}->{lib};

die "No library defined in file '$config_file'"
  unless defined $LIB;
die "Invalid library name '$LIB' in file '$config_file'"
  unless $LIB =~ /^[A-Za-z]\w*(::\w+)*\z/;

# Read the reference type(s) the library uses.

our $REF = $config->{_}->{ref};

die "No reference type defined in file '$config_file'"
  unless defined $REF;
die "Invalid reference type '$REF' in file '$config_file'"
  unless $REF =~ /^[A-Za-z]\w*(::\w+)*\z/;

# Load the library.

eval "require $LIB";
die $@ if $@;

###############################################################################

my $scalar_util_ok = eval { require Scalar::Util; };
Scalar::Util -> import('refaddr') if $scalar_util_ok;

diag "Skipping some tests since Scalar::Util is not installed."
  unless $scalar_util_ok;

can_ok($LIB, '_log_int');

my @data;

# Small numbers.

for (my $x = 0; $x <= 1000 ; ++ $x) {
    for (my $b = 0; $b <= 10 ; ++ $b) {

        if ($x == 0 || $b <= 1) {
            push @data, [ $x, $b, undef, undef ];
            next;
        }

        my $y = int(log($x) / log($b));
        $y++ while $b ** $y < $x;
        $y-- while $b ** $y > $x;
        my $status = $b ** $y == $x ? 1 : 0;
        push @data, [ $x, $b, $y, $status ];
    }
}

# Larger numbers.

for (my $b = 2 ; $b <= 100 ; $b++) {
    my $bobj = $LIB -> _new($b);
    for (my $y = 2 ; $y <= 10 ; $y++) {
        my $x    = $LIB -> _pow($LIB -> _copy($bobj), $LIB -> _new($y));
        my $x_up = $LIB -> _inc($LIB -> _copy($x));
        my $x_dn = $LIB -> _dec($LIB -> _copy($x));
        push @data, [ $LIB -> _str($x),    $b, $y,     1 ];
        push @data, [ $LIB -> _str($x_up), $b, $y,     0 ];
        push @data, [ $LIB -> _str($x_dn), $b, $y - 1, 0 ];
    }
}

# List context.

for (my $i = 0 ; $i <= $#data ; ++ $i) {
    my ($in0, $in1, $out0, $out1) = @{ $data[$i] };

    my ($x, $y, @got);

    my $test = qq|\$x = $LIB->_new("$in0"); |
             . qq|\$y = $LIB->_new("$in1"); |
             . qq|\@got = $LIB->_log_int(\$x, \$y);|;

    diag("\n$test\n\n") if $ENV{AUTHOR_DEBUGGING};

    eval $test;
    is($@, "", "'$test' gives emtpy \$\@");

    subtest "_log_int() in list context: $test", sub {

        unless (defined $out0) {
            plan tests => 1;

            is($got[0], $out0,
               "'$test' output arg has the right value");
            return;
        }

        plan tests => 11;

        # Number of input arguments.

        cmp_ok(scalar @got, '==', 2,
               "'$test' gives two output args");

        # First output argument.

        is(ref($got[0]), $REF,
           "'$test' first output arg is a $REF");

        is($LIB->_check($got[0]), 0,
           "'$test' first output is valid");

        is($LIB->_str($got[0]), $out0,
           "'$test' output arg has the right value");

      SKIP: {
            skip "Scalar::Util not available", 1 unless $scalar_util_ok;

            isnt(refaddr($got[0]), refaddr($y),
                 "'$test' first output arg is not the second input arg")
        }

        is(ref($x), $REF,
           "'$test' first input arg is still a $REF");

        ok($LIB->_str($x) eq $out0 || $LIB->_str($x) eq $in0,
           "'$test' first input arg has the correct value");

        is(ref($y), $REF,
           "'$test' second input arg is still a $REF");

        is($LIB->_str($y), $in1,
           "'$test' second input arg is unmodified");

        # Second output argument.

        is(ref($got[1]), "",
           "'$test' second output arg is a scalar");

        is($got[1], $out1,
           "'$test' second output arg has the right value");
    };
}
