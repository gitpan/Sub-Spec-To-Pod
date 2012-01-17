use Package::Alias 'Sub::Spec::To::Pod' => 'Sub::Spec::To::POD';
package Sub::Spec::To::Pod;
{
  $Sub::Spec::To::Pod::VERSION = '0.20';
}
use vars qw(@ISA @EXPORT @EXPORT_OK);
@ISA       = @Sub::Spec::To::POD::ISA;
@EXPORT    = @Sub::Spec::To::POD::EXPORT;
@EXPORT_OK = @Sub::Spec::To::POD::EXPORT_OK;
1;
# ABSTRACT: Now an alias to Sub::Spec::To::POD

__END__
=pod

=head1 NAME

Sub::Spec::To::Pod - Now an alias to Sub::Spec::To::POD

=head1 VERSION

version 0.20

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

