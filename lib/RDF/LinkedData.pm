package RDF::LinkedData;

# Next line is a workaround to problem documented in Error.pm#COMPATIBILITY
BEGIN { require Moose; Moose->import; *with_role = *with; undef *with };

with_role 'RDF::LinkedData::ProviderRole';


=head1 NAME

RDF::LinkedData - A Linked Data server implementation

=head1 VERSION

Version 0.21_5

=cut

our $VERSION = '0.21_5';


=head1 SYNOPSIS

A simple L<Plack> server illustrates the usage nicely:

  use RDF::LinkedData;
  use Plack::Request;
  use RDF::Trine;

  my $parser = RDF::Trine::Parser->new( 'turtle' );
  my $model = RDF::Trine::Model->temporary_model;
  my $base_uri = 'http://localhost:5000';
  $parser->parse_file_into_model( $base_uri, 't/data/basic.ttl', $model );
  my $ld = RDF::LinkedData->new(model => $model, base_uri=>$base_uri);

  my $linked_data = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $uri = $req->path_info;
    if ($req->path_info =~ m!^(.+?)/?(page|data)$!) {
        $uri = $1;
        $ld->type($2);
    }
    $ld->headers_in($req->headers);
    return $ld->response($uri)->finalize;
  }


=head1 DESCRIPTION

This class provides a server implementation for serving Linked Data
from the host it is configured for. Its main feature is that it can
take an RDF model optionally read from file(s) or from a SPARQL
endpoint and serve the URIs of those resources according to Linked
Data best practices. It will do content negotation, supports many
seralizations, and it will do 303 redirects as needed.

For example, say you control a host C<lod.example.org> and wish to use
it to serve Linked Data. On file, you have a bit of RDF that you want
to serve, like:

  @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

  <http://lod.example.org/foo> rdfs:label "DAHUT" ;
                               rdfs:seeAlso <http://lod.example.org/bar> .
  <http://lod.example.org/bar> rdfs:label "More here" .

Then configuring this server to use the above file will make
C<http://lod.example.org/foo> and C<http://lod.example.org/bar>
dereferenceable with no further effort. The server will also return an
appropriate 303 redirect to either a C<data> or C<page> suffix
depending on the client's C<Accept> header and return a representation
of the data.


=head1 METHODS

This module simply uses the default implementation in
L<RDF::LinkedData::ProviderRole>, and does nothing on its
own. However, there is a quirk which is only relevant to a developer
of this package.

=over

=item with_role

I had to redefine L<Moose::Role>'s with due to a conflict with
L<Error> described in the documentation of the latter. Users will
never see this.

=back

=head1 AUTHOR

This module was started by by Gregory Todd Williams C<<
<gwilliams@cpan.org> >> for L<RDF::LinkedData::Apache>, but heavily
refactored and rewritten by Kjetil Kjernsmo, C<< <kjetilk@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-rdf-linkeddata at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RDF-LinkedData>.  I
will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 WARNING

Do not rely in the current API unless you are planning to keep track
of the development of this module. It is still very much in flux, and
may change without warning!



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RDF::LinkedData

The perlrdf mailing list is the right place to seek help and discuss this module:

L<http://lists.perlrdf.org/listinfo/dev>

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=RDF-LinkedData>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/RDF-LinkedData>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/RDF-LinkedData>

=item * Search CPAN

L<http://search.cpan.org/dist/RDF-LinkedData>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2010-2011 Kjetil Kjernsmo, Gregory Todd Williams and ABC Startsiden AS.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;

1; # End of RDF::LinkedData
