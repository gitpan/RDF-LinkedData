#line 1
package Module::Install::RDF;

use 5.005;
use base qw(Module::Install::Base);
use strict;

our $VERSION = '0.007';
our $AUTHOR_ONLY = 1;

sub rdf_metadata
{
	my $self = shift;
	$self->admin->rdf_metadata(@_) if $self->is_admin;
}

1;

__END__
#line 60
