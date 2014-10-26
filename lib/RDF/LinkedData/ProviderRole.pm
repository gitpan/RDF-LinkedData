package RDF::LinkedData::ProviderRole;

# Next line is a workaround to problem documented in Error.pm#COMPATIBILITY
BEGIN { require Moose::Role; Moose::Role->import; *with_role = *with; undef *with };

use namespace::autoclean;

use RDF::Trine;
use RDF::Trine::Serializer;
use Log::Log4perl qw(:easy);
use Plack::Response;
use RDF::Helper::Properties;
use URI;
use Module::Load::Conditional qw[can_load];

with_role 'MooseX::Log::Log4perl::Easy';

BEGIN {
  if ($ENV{TEST_VERBOSE}) {
    Log::Log4perl->easy_init( { level   => $TRACE } );
  } else {
    Log::Log4perl->easy_init( { level   => $FATAL } );
  }
}




=head1 NAME

RDF::LinkedData::ProviderRole - Role providing important functionality for Linked Data implementations

=head1 VERSION

Version 0.30

=cut

our $VERSION = '0.30';


=head1 SYNOPSIS

See L<RDF::LinkedData> for default usage.


=head1 DISCUSSION

This module is now a L<Moose::Role>. The intention with this role is threefold:

=over

=item * This module may run standalone, in which case the default
implementation in this role should be sufficient for a working Linked
Data server. The empty L<RDF::LinkedData> class should provide such a
default implementation.

=item * This role may be implemented in classes that need to change
some parts of its functionality, such as a L<mod_perl>-based server.

=item * It may be a part of a larger server framework, for example a
server that supports the SPARQL protocol and the SPARQL RESTful
protocol.

=back

It is not completely clear at this point what the requirements are for
these three scenarios, but it currently satisfies the first
scenario. Thus, the role may need to be changed substantially and
possibly split into different roles based on the usage that evolves
over time.

Consequently, one should not rely in the current API unless you are
planning to keep track of the development of this module. It is still
very much in flux, and may change without warning. Just installing and
using it as a Linked Data server should be OK, however, as its
important functionality is unlikely to change in non-backwards
compatible ways.


=head1 METHODS

=over

=item C<< new ( store => $store, model => $model, base_uri => $base_uri, 
                request => $request, endpoint_config => $endpoint_config ) >>

Creates a new handler object based on named parameters, given a store
config (recommended usage is to pass a hashref of the type that can be
passed to L<RDF::Trine::Store>->new_with_config, but a simple string
can also be used) or model and a base URI. Optionally, you may pass a
L<Plack::Request> object (must be there if you if you plan to call
C<content>) and an C<endpoint_config> hashref if you want to have a
SPARQL Endpoint running using the recommended module L<RDF::Endpoint>.

=cut

sub BUILD {
	my $self = shift;

        unless($self->model) {
	  # First, set the base if none is configured
	  my $i = 0;
	  foreach my $source (@{$self->store->{sources}}) {
	    unless ($source->{base_uri}) {
	      ${$self->store->{sources}}[$i]->{base_uri} = $self->base_uri;
	    }
	    $i++;
	  }
	  my $store	= RDF::Trine::Store->new( $self->store );
	  $self->model(RDF::Trine::Model->new( $store ));
	}

        throw Error -text => "No valid RDF::Trine::Model, need either a store config hashref or a model." unless ($self->model);

 	if ($self->has_endpoint_config) {
	  use Data::Dumper;
	  $self->logger->debug('Endpoint config found with parameters: ' . Dumper($self->endpoint_config) );

 	  unless (can_load( modules => { 'RDF::Endpoint' => 0.03 })) {
 	    throw Error -text => "RDF::Endpoint not installed. Please install or remove its configuration.";
 	  }
 	  $self->endpoint(RDF::Endpoint->new($self->model, $self->endpoint_config));
 	} else {
	  $self->logger->info('No endpoint config found');
	}
}

has store => (is => 'rw', isa => 'HashRef' );

has endpoint_config => (is => 'ro', isa=>'HashRef', predicate => 'has_endpoint_config');

=item C<< endpoint ( [ $endpoint ] ) >>

Returns the L<RDF::Endpoint> object if it exists or sets it if a
L<RDF::Endpoint> object is given as parameter. In most cases, it will
be created for you if you pass a C<endpoint_config> hashref to the
constructor, so you would most likely not use this method.

=cut


has endpoint => (is => 'rw', isa => 'RDF::Endpoint', predicate => 'has_endpoint');


=item C<< request ( [ $request ] ) >>

Returns the L<Plack::Request> object if it exists or sets it if a L<Plack::Request> object is given as parameter.

=cut

has request => ( is => 'rw', isa => 'Plack::Request');



=item C<< helper_properties (  ) >>

Returns the L<RDF::Helper::Properties> object if it exists or sets
it if a L<RDF::Helper::Properties> object is given as parameter.

=cut

has helper_properties => ( is => 'rw', isa => 'RDF::Helper::Properties', lazy => 1, builder => '_build_helper_properties');

sub _build_helper_properties {
    my $self = shift;
    return RDF::Helper::Properties->new(model => $self->model);
}



=item C<< type >>

Returns or sets the type of result to return, i.e. C<page>, in the case of a human-intended page or C<data> for machine consumption, or an empty string if it is an actual resource URI that should be redirected.

=cut

#requires 'type';

has 'type' => (is => 'rw', isa => 'Str', default => ''); 


=item C<< my_node >>

A node for the requested URI. This node is typically used as the
subject to find which statements to return as data. This expects to
get a URI object containing the full URI of the node.

=cut

sub my_node {
    my ($self, $iri) = @_;
    
    # not happy with this, but it helps for clients that do content sniffing based on filename
    $iri	=~ s/.(nt|rdf|ttl)$//;
    $self->logger->info("Subject URI to be used: $iri");
    return RDF::Trine::Node::Resource->new( $iri );
}

=item C<< count ( $node) >>

Returns the number of statements that has the $node as subject, or all if $node is undef.

=cut


sub count {
    my $self = shift;
    my $node = shift;
    return $self->model->count_statements( $node, undef, undef );
}

=item C<< content ( $node, $type) >>

Will return the a hashref with content for this URI, based on the
$node subject, and the type of node, which may be either C<data> or
C<page>. In the first case, an RDF document serialized to a format set
by content negotiation. In the latter, a simple HTML document will be
returned. The returned hashref has two keys: C<content_type> and
C<body>. The former is self-explanatory, the latter contains the
actual content.

One may argue that a hashref with magic keys should be a class of its
own, and for that reason, this method should be considered "at
risk". Currently, it is only used in one place, and it may be turned
into a private method, get passed the L<Plack::Response> object,
removed altogether or turned into a role of its own, depending on the
actual use cases that surfaces in the future.

=cut


sub content {
    my ($self, $node, $type) = @_;
    my $model = $self->model;
    my %output;
    if ($type eq 'data') {
        $self->{_type} = 'data';
        my ($type, $s) = RDF::Trine::Serializer->negotiate('request_headers' => $self->request->headers,
                                                           base => $self->base_uri,
                                                           namespaces => $self->namespaces);
        my $iter = $model->bounded_description($node);
        $output{content_type} = $type;
        $output{body} = $s->serialize_iterator_to_string ( $iter );
    } else {
        $self->{_type} = 'page';
        my $preds = $self->helper_properties;
        my $title		= $preds->title( $node );
        my $desc		= $preds->description( $node );
        my $description	= sprintf('<table about="'. $node->uri_value  .'"' .">%s</table>\n", 
				  join("\n\t\t", map { sprintf( '<tr><td>%s</td><td>%s</td></tr>', @$_ ) } @$desc) );
        $output{content_type} = 'text/html';
        $output{body} =<<"END";
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN"
	 "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>${title}</title>
</head>
<body xmlns:foaf="http://xmlns.com/foaf/0.1/">

<h1>${title}</h1>
<hr/>

<div>
	${description}
</div>

</body></html>
END
    }     
    return \%output;
}




=item C<< model >>

Returns or sets the RDF::Trine::Model object.

=cut

has model => (is => 'rw', isa => 'RDF::Trine::Model');

=item C<< base_uri >>

Returns or sets the base URI for this handler.

=cut

has base_uri => (is => 'rw', isa => 'Str' );


=item C<< response ( $uri ) >>

Will look up what to do with the given URI object and populate the
response object.

=cut

sub response {
    my $self = shift;
    my $uri = URI->new(shift);
    my $response = Plack::Response->new;

    my $headers_in = $self->request->headers;
    my $endpoint_path = '/sparql';
    if ($self->has_endpoint_config && defined($self->endpoint_config->{endpoint_path})) {
      my $endpoint_path = $self->endpoint_config->{endpoint_path};
    }

    if($self->has_endpoint && ($uri->path eq $endpoint_path)) {
      return $self->endpoint->run( $self->request );
    }

    my $type = $self->type;
    $self->type('');
    my $node = $self->my_node($uri);
    $self->logger->info("Try rendering '$type' page for subject node: " . $node->as_string);
    if ($self->count($node) > 0) {
        if ($type) {
            my $preds = $self->helper_properties;
            my $page = $preds->page($node);
            if (($type eq 'page') && ($page ne $node->uri_value . '/page')) {
                # Then, we have a foaf:page set that we should redirect to
                $response->status(301);
                $response->headers->header('Location' => $page);
                $response->headers->header('Access-Control-Allow-Origin' => '*');
                return $response;
            }

            $self->logger->debug("Will render '$type' page ");
            if ($headers_in->can('header') && $headers_in->header('Accept')) {
                $self->logger->debug('Found Accept header: ' . $headers_in->header('Accept'));
            } else {
                $headers_in->header(HTTP::Headers->new('Accept' => 'application/rdf+xml'));
                $self->logger->warn('Setting Accept header: ' . $headers_in->header('Accept'));
            }
            $response->status(200);
            my $content = $self->content($node, $type);
            $response->headers->header('Vary' => join(", ", qw(Accept)));
            $response->headers->content_type($content->{content_type});
            $response->content($content->{body});
        } else {
            $response->status(303);
            my ($ct, $s);
            eval {
                ($ct, $s) = RDF::Trine::Serializer->negotiate('request_headers' => $headers_in,
                                                          base => $self->base_uri,
                                                          namespaces => $self->namespaces,
							  extend => {
								     'text/html'	=> 'html',
								     'application/xhtml+xml' => 'html'
								    }
							  )
	      };
            $self->logger->debug("Got $ct content type");
            if ($@) {
	      $response->status(406);
	      $response->headers->content_type('text/plain');
	      $response->body('HTTP 406: No serialization available any specified content type');
	      return $response;
            }
            my $newurl = $uri . '/data';
            unless ($s->isa('RDF::Trine::Serializer')) {
                my $preds = $self->helper_properties;
                $newurl = $preds->page($node);
            }
            $self->logger->debug('Will do a 303 redirect to ' . $newurl);
            $response->headers->header('Location' => $newurl);
            $response->headers->header('Vary' => join(", ", qw(Accept)));
        }
	$response->headers->header('Access-Control-Allow-Origin' => '*');
        return $response;
    } else {
        $response->status(404);
        $response->headers->content_type('text/plain');
        $response->body('HTTP 404: Unknown resource');
        return $response;
      }
    # We should never get here.
    $response->status(500);
    $response->headers->content_type('text/plain');
    $response->body('HTTP 500: No such functionality.');
    return $response;
}


=item namespaces ( { skos => 'http://www.w3.org/2004/02/skos/core#', dct => 'http://purl.org/dc/terms/' } )

Gets or sets the namespaces that some serializers use for pretty-printing.

=cut



has 'namespaces' => (is => 'rw', isa => 'HashRef', default => sub { { rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' } } );


=back


=head1 AUTHOR

This module was started by by Gregory Todd Williams C<<
<gwilliams@cpan.org> >> for L<RDF::LinkedData::Apache>, but heavily
refactored and rewritten by by Kjetil Kjernsmo, C<< <kjetilk@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-rdf-linkeddata at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RDF-LinkedData>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RDF::LinkedData::ProviderRole

The perlrdf mailing list is the right place to seek help and discuss this module:

L<http://lists.perlrdf.org/listinfo/dev>


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2010-2011 Kjetil Kjernsmo, Gregory Todd Williams and ABC Startsiden AS.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
