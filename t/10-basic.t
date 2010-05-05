#!/usr/bin/perl

use FindBin qw($Bin);
use HTTP::Headers;

use strict;
use Test::More tests => 17;
use Test::Exception;

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

my $ld = RDF::LinkedData->new(model => $model, base=>$base_uri);

isa_ok($ld, 'RDF::LinkedData');
is($ld->count, 2, "There are 2 triples in model");
is_deeply($ld->model, $model, "The model is still the model");

is($ld->base, $base_uri, "The base is still the base");

my $node = $ld->my_node('/foo');

is($node->uri_value, 'http://localhost:3000/foo', "URI is still there");

isa_ok($node, 'RDF::Trine::Node::Resource');


is($ld->title($node), 'This is a test', "Correct title");

{
    my $h = HTTP::Headers->new(Accept	=> 'application/rdf+xml');
    my $ldh = $ld;
    $ldh->headers($h);
    my $content = $ldh->content($node, 'data');

    is($content->{content_type}, 'application/rdf+xml', "RDF/XML content type");
}

{
    my $h = HTTP::Headers->new(Accept	=> 'application/turtle');
    my $ldh = $ld;
    $ldh->headers($h); 
    my $content = $ldh->content($node, 'data');
    is($content->{content_type}, 'application/turtle', "NTriples content type"); # TODO: is this correct?
    is($content->{body}, '<http://localhost:3000/foo> <http://www.w3.org/2000/01/rdf-schema#label> "This is a test"@en .' . "\n", 'Ntriples serialized correctly');
}

{
    my $h = HTTP::Headers->new(Accept	=> 'text/html');
    my $ldh = $ld;
    $ldh->headers($h); 
    TODO: {
          local $TODO = "What should really be done with a text/html request for data?";
          my $content;
          lives_ok{ $content = $ldh->content($node, 'data') }, "Should give us a way to give a 406";
          is($content->{content_type}, 'application/rdf+xml', "Data type overrides and gives RDF/XML"); # TODO: is this correct?
    }
    {
        my $content = $ldh->content($node, 'page');
        is($content->{content_type}, 'text/html', "Page gives HTML");
    }
}



done_testing();
