package Syntax::Each::PerOp;

use strict;
use warnings;
use Exporter 'import';
use Devel::Callsite;
use Scalar::Util qw(refaddr reftype);

our $VERSION = '0.001';

our @EXPORT = 'each';

my %iterators;

sub each (\[@%]) {
  my ($structure) = @_;
  my $id = join '$', callsite(), context(), refaddr($structure);
  my $is_hash = reftype($structure) eq 'HASH';
  $iterators{$id} = [$is_hash ? keys %$structure : 0..$#$structure]
    unless exists $iterators{$id};
  if (@{$iterators{$id}}) {
    my $key = shift @{$iterators{$id}};
    return wantarray ? ($key, $is_hash ? $structure->{$key} : $structure->[$key]) : $key;
  } else {
    delete $iterators{$id};
    return ();
  }
}

1;

=head1 NAME

Syntax::Each::PerOp - A per-op each function

=head1 SYNOPSIS

  use Syntax::Each::PerOp;
  
  while (my ($k, $v) = each %stuff) {
    # these now will not break the loop
    my $all_keys = keys %stuff;
    my $all_values = values %stuff;
    my %copy = %stuff;
    my @keys_and_values = %stuff;
    # and is re-entrant
    while (my ($inner_k, $inner_v) = each %stuff) {
      ...
    }
  }
  
  # other normal usage supported
  while (defined(my $key = each %stuff)) { ... }
  while (my ($i, $e) = each @stuff) { ... }
  while (defined(my $index = each @stuff)) { ... }

=head1 DESCRIPTION

The L<each|perlfunc/each> function can be problematic as it is implemented as
an iterator in the hash or array itself. This means it cannot be nested as the
iterator will be shared between the loops. Furthermore, the
L<keys|perlfunc/keys> and L<values|perlfunc/values> functions share this
iterator and reset it when called, as does accessing the hash in list context,
so these cause problems during such a loop. This module provides an L</each>
function that iterates locally to the op (position in the code) itself, as well
as the data structure it is called on, so it can be nested in itself and will
not be affected by list access to the hash's keys or values.

=head1 FUNCTIONS

The L</each> function is exported by default.

=head2 each

  while (my ($key, $value) = each %hash) {
  while (defined(my $key = each %hash)) {
  while (my ($index, $element) = each @array) {
  while (defined(my $index = each @array) {

Returns the next key-value (or index-element) pair in list context, or
key/index in scalar context, of the given hash or array. When the iteration has
completed, returns an empty list, or C<undef> in scalar context. The next call
after completing the iteration will start a new iteration.

The keys or indices of the data structure are stored for iteration when C<each>
begins a new iteration, so deleting or adding elements will not affect an
ongoing iteration.

=head1 CAVEATS

As this version of C<each> is tied to the op that calls it as well as the data
structure it's called on, it will not conflict with calls on the same data
structure in different locations in the code, but it can still conflict with
calls in the same location. This can occur if the C<each> call is in a loop or
function, and that code is called again on the same data structure before it
has completed iterating, such as via a recursive function call or loop control
operations, or if the C<each> loop had exited early. When this happens, it will
resume the same iteration. This is also true of the core C<each> function since
it is only tied to the data structure. However, unlike the core function which
can be reset manually to work around this issue by calling
L<keys|perlfunc/keys> or L<values|perlfunc/values> on the data structure, it is
not possible to reset this function's iterator except by allowing it to iterate
to the end.

  my %fruit_colors = (...);
  sub check_colors {
    COLOR: foreach my $color (@_) {
      while (my ($fruit, $fruit_color) = each %fruit_colors) {
        last if $fruit_color eq $color;                 # boom! iteration will not restart
        next COLOR if $fruit_color eq 'blue';           # same
        check_colors('taupe') unless $color eq 'taupe'; # also will break this iteration
      }
    }
  }

Since this version of C<each> will not be implicitly wrapped in a C<defined>
check when alone in a while loop condition, you must explicitly check if the
return value is defined when iterating over the scalar-context form of this
function, to avoid inadvertently halting the loop when a falsey key or index is
returned.

  while (my $key = each %hash) {          # wrong
  while (defined(my $key = each %hash)) { # right

C<each> calls L<keys|perlfunc/keys> internally when iterating over a hash, so
it will reset the iterator used by the core L<each|perlfunc/each> function on
that data structure. So it is not safe to nest this version of C<each> within
the core C<each> function called on the same structure, just as it is not safe
to nest the core C<each> in itself.

The behavior of implicitly assigning the key/index to C<$_> when called without
assignment in a while loop condition is not supported.

The C<autoderef> experimental feature (removed in perl 5.24) to allow C<each>
to take a reference to a hash or array is also not supported.

I am not sure whether or how this function works with threads or tied
structures. Patches welcome.

=head1 BUGS

Report any issues on the public bugtracker.

=head1 AUTHOR

Dan Book <dbook@cpan.org>

=head1 CREDITS

L<Var::Pairs/"each_pair"> by Damian Conway for inspiration.

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by Dan Book.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=head1 SEE ALSO

L<Perl::Critic::Policy::Freenode::Each>,
L<http://blogs.perl.org/users/rurban/2014/04/do-not-use-each.html>
