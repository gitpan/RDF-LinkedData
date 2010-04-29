#!/usr/bin/perl

use FindBin qw($Bin);

use strict;
use Test::More;# tests => 6;

my $file = $Bin . '/data/basic.ttl';

BEGIN {
    use_ok('RDF::LinkedData');
    use_ok('RDF::Trine::Parser');
    use_ok('RDF::Trine::Model');
}

my $parser     = RDF::Trine::Parser->new( 'turtle' );
my $model = RDF::Trine::Model->temporary_model;
my $base_uri = 'http://localhost:3000';
$parser->parse_file_into_model( $base_uri, $file, $model );

ok($model, "We have a model");

my $ld = RDF::LinkedData->new($model, $base_uri);

isa_ok($ld, 'RDF::LinkedData');
is($ld->count, 2, "There are 2 triples in model");

is_deeply($ld->model, $model, "The model is still the model");

is($ld->base, $base_uri, "The base is still the base");

my $node = $ld->my_node('/foo');

is($node->uri_value, 'http://localhost:3000/foo', "URI is still there");

isa_ok($node, 'RDF::Trine::Node::Resource');

is($ld->title($node), 'This is a test', "Correct title");

{
    local($ENV{HTTP_ACCEPT})	= 'application/rdf+xml';
    is($ld->negotiate, 'rdf-xml', 'Negotiate gives RDF/XML');
    my $content = $ld->content($node, 'data');
    is($content->{content_type}, 'application/rdf+xml', "RDF/XML content type");
}

{
    local($ENV{HTTP_ACCEPT})	= 'application/turtle';
    is($ld->negotiate, 'rdf-nt', 'Negotiate gives Ntriples for Turtle');
    my $content = $ld->content($node, 'data');
    is($content->{content_type}, 'text/n3', "NTriples content type"); # TODO: is this correct?
    is($content->{body}, '# Data for http://localhost:3000/foo' . "\n" .'<http://localhost:3000/foo> <http://www.w3.org/2000/01/rdf-schema#label> "This is a test"@en .' . "\n", 'Ntriples serialized correctly');
}

{
    local($ENV{HTTP_ACCEPT})	= 'text/html';
    is($ld->negotiate, 'html', 'Negotiate gives HTML');
    {
        my $content = $ld->content($node, 'data');
        is($content->{content_type}, 'application/rdf+xml', "Data type overrides and gives RDF/XML"); # TODO: is this correct?
    }
    {
        my $content = $ld->content($node, 'page');
        is($content->{content_type}, 'text/html', "Page gives HTML");
    }
}


TODO: {
    local $TODO = "Should have a separate Turtle serialisation";
    local($ENV{HTTP_ACCEPT})	= 'application/turtle';
    is($ld->negotiate, 'rdf-turtle', 'Negotiate gives Turtle');
}



done_testing();
