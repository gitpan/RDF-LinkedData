#line 1
package Module::Install::DOAP;

use 5.008;
use base qw(Module::Install::Base);
use strict;

our $VERSION = '0.004';
our $AUTHOR_ONLY = 1;

sub doap_metadata
{
	my $self = shift;
	$self->admin->doap_metadata(@_) if $self->is_admin;
}

1;

__END__
#line 56
