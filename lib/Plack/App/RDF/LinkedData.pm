package Plack::App::RDF::LinkedData;
use strict;
use warnings;
use parent qw( Plack::Component );
use RDF::LinkedData;
use Plack::Request;

=head1 NAME

Plack::App::RDF::LinkedData - A Plack application for running RDF::LinkedData

=head1 SYNOPSIS

  my $linkeddata = Plack::App::RDF::LinkedData->new();
  $linkeddata->configure($config);
  my $rdf_linkeddata = $linkeddata->to_app;

  builder {
     enable "Head";
	  enable "ContentLength";
	  enable "ConditionalGET";
	  $rdf_linkeddata;
  };

=head1 DESCRIPTION

This module sets up a basic Plack application to use
L<RDF::LinkedData> to serve Linked Data, while making sure it does
follow best practices for doing so.

=head1 MAKE IT RUN

=head2 Configuration

Create a configuration file C<rdf_linkeddata.json> that looks something like:

  {
        "base_uri"  : "http://localhost:3000/",
        "store" : {
                   "storetype"  : "Memory",
                   "sources" : [ {
                                "file" : "/path/to/your/data.ttl",
                                "syntax" : "turtle"
                               } ]

                   },
        "endpoint": {
        	"html": {
	                 "resource_links": true
	                }
                    },
        "cors": {
                  "origins": "*"
                }
  }

In your shell set

  export RDF_LINKEDDATA_CONFIG=/to/where/you/put/rdf_linkeddata.json

Then, figure out where your install method installed the
<linked_data.psgi>, script, e.g. by using locate. If it was installed
in C</usr/local/bin>, go:

  plackup /usr/local/bin/linked_data.psgi --host localhost --port 3000

The C<endpoint>-part of the config sets up a SPARQL Endpoint. This requires
the L<RDF::Endpoint> module, which is recommended by this module. To
use it, it needs to have some config, but will use defaults.

The last, C<cors>-part of the config enables Cross-Origin Resource
Sharing, which is a W3C draft for relaxing security constraints to
allow data to be shared across domains. In most cases, this is what
you want when you are serving open data, but in some cases, notably
intranets, this should be turned off by removing this part.

=head2 Details of the implementation

This server is a minimal Plack-script that should be sufficient for
most linked data usages, and serve as a an example for most others.

A minimal example of the required config file is provided above. There
is a long example in the distribtion, which is used to run tests. In
the config file, there is a C<store> parameter, which must contain the
L<RDF::Trine::Store> config hashref. It may also have a C<base_uri> URI
and a C<namespace> hashref which may contain prefix - URI mappings to
be used in serializations.

Note that this is a server that can only serve URIs of hosts you
control, it is not a general purpose Linked Data manipulation tool,
nor is it a full implementation of the L<Linked Data API|http://code.google.com/p/linked-data-api/>.

The configuration is done using L<Config::JFDI> and all its features
can be used. Importantly, you can set the C<RDF_LINKEDDATA_CONFIG>
environment variable to point to the config file you want to use. See
also L<Catalyst::Plugin::ConfigLoader> for more information on how to
use this config system.

=head2 Behaviour

The following documentation is adapted from the L<RDF::LinkedData::Apache>,
which preceeded this script.

=over 4 

=item * C<http://host.name/rdf/example>

Will return an HTTP 303 redirect based on the value of the request's
Accept header. If the Accept header contains a recognized RDF media
type or there is no Accept header, the redirect will be to
C<http://host.name/rdf/example/data>, otherwise to
C<http://host.name/rdf/example/page>. If the URI has a foaf:homepage
or foaf:page predicate, the redirect will in the latter case instead
use the first encountered object URI.

=item * C<http://host.name/rdf/example/data>

Will return a bounded description of the C<http://host.name/rdf/example>
resource in an RDF serialization based on the Accept header. If the Accept
header does not contain a recognized media type, RDF/XML will be returned.

=item * C<http://host.name/rdf/example/page>

Will return an HTML description of the C<http://host.name/rdf/example>
resource including RDFa markup, or, if the URI has a foaf:homepage or
foaf:page predicate, a 301 redirect to that object.

=back

If the RDF resource for which data is requested is not the subject of any RDF
triples in the underlying triplestore, the /page and /data redirects will not take
place, and a HTTP 404 (Not Found) will be returned.

The HTML description of resources will be enhanced by having metadata
about the predicate of RDF triples loaded into the same
triplestore. Currently, only a C<rdfs:label>-predicate will be used
for a title, as in this version, generation of HTML is done by
L<RDF::RDFa::Generator>.

=head2 Endpoint Usage

As stated earlier, this module can set up a SPARQL Endpoint for the
data using L<RDF::Endpoint>. Often, that's what you want, but if you
don't want your users to have that kind of power, or you're worried it
may overload your system, you may turn it off by simply having no
C<endpoint> section in your config. To use it, you just need to have
an C<endpoint> section with something in it, it doesn't really matter
what, as it will use defaults for everything that isn't set.

L<RDF::Endpoint> is recommended by this module, but as it is optional,
you may have to install it separately. It has many configuration
options, please see its documentation for details.

You may also need to set the C<RDF_ENDPOINT_SHAREDIR> variable to
whereever the endpoint shared files are installed to. These are some
CSS and Javascript files that enhance the user experience. They are
not strictly necessary, but it sure makes it pretty! L<RDF::Endpoint>
should do the right thing, though, so it shouldn't be necessary.

Finally, note that while L<RDF::Endpoint> can serve these files for
you, this module doesn't help you do that. That's mostly because this
author thinks you should serve them using some other parts of the
deployment stack. For example, to use Apache, put this in your Apache
config in the appropriate C<VirtualHost> section:


  Alias /js/ /path/to/share/www/js/
  Alias /favicon.ico /path/to/share/www/favicon.ico
  Alias /css/ /path/to/share/www/css/


=head1 FEEDBACK WANTED

Please contact the author if this documentation is unclear. It is
really very simple to get it running, so if it appears difficult, this
documentation is most likely to blame.



=head1 METHODS

You would most likely not need to call these yourself, but rather use
the C<linked_data.psgi> script supplied with the distribution.

=over

=item C<< configure >>

This is the only method you would call manually, as it can be used to
pass a hashref with configuration to the application.

=cut

sub configure {
	my $self = shift;
	$self->{config} = shift;
	return $self;
}


=item C<< prepare_app >>

Will be called by Plack to set the application up.

=item C<< call >>

Will be called by Plack to process the request.

=back

=cut


sub prepare_app {
	my $self = shift;
	my $config = $self->{config};
	$self->{linkeddata} = RDF::LinkedData->new(store => $config->{store},
															 endpoint_config => $config->{endpoint},
															 void_config => $config->{void},
															 base_uri => $config->{base_uri}
															);
	$self->{linkeddata}->namespaces($config->{namespaces}) if ($config->{namespaces});
}

sub call {
	my($self, $env) = @_;
	my $req = Plack::Request->new($env);
	my $ld = $self->{linkeddata};
	unless (($req->method eq 'GET') || ($req->method eq 'HEAD')) {
		return [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ];
	}

	my $uri = $req->uri;
	if ($uri->as_iri =~ m!^(.+?)/?(page|data)$!) {
		$uri = URI->new($1);
		$ld->type($2);
	}
	$ld->request($req);
	return $ld->response($uri)->finalize;
}

1;



=head1 AUTHOR

Kjetil Kjernsmo, C<< <kjetilk@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010-2012 Kjetil Kjernsmo

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut
