#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 29 ;
use Test::WWW::Mechanize::Mojo;

require 'script/linked_data_mojoserver.pl';


my $tester = Test::Mojo->new();

{
    my $mech = Test::WWW::Mechanize::Mojo->new(tester => $tester, requests_redirectable => []);
    my $res = $mech->get("/foo");
    is($mech->status, 303, "Returns 303");
    like($res->header('Location'), qr|/foo/page$|, "Location is OK");
}

{
    my $mech = Test::WWW::Mechanize::Mojo->new(tester => $tester, requests_redirectable => []);
    $mech->default_header('Accept' => 'application/rdf+xml');
    my $res = $mech->get("/foo");
    is($mech->status, 303, "Returns 303");
    like($res->header('Location'), qr|/foo/data$|, "Location is OK");
}

{
    my $mech = Test::WWW::Mechanize::Mojo->new(tester => $tester, requests_redirectable => []);
    $mech->default_header('Accept' => 'application/rdf+xml');
    my $res = $mech->get("/dahut");
    is($mech->status, 404, "Returns 404");
}

{
    my $mech = Test::WWW::Mechanize::Mojo->new(tester => $tester);
    $mech->get_ok("/foo");
    is($mech->ct, 'text/html', "Correct content-type");
    like($mech->uri, qr|/foo/page$|, "Location is OK");
    $mech->title_is('This is a test', "Title is correct");
}

{
    my $mech = Test::WWW::Mechanize::Mojo->new(tester => $tester);
    $mech->default_header('Accept' => 'application/rdf+xml');
    $mech->get_ok("/foo");
    is($mech->ct, 'application/rdf+xml', "Correct content-type");
    like($mech->uri, qr|/foo/data$|, "Location is OK");
    $mech->content_contains('This is a test', "Test phrase in content");
}

{
    my $mech = Test::WWW::Mechanize::Mojo->new(tester => $tester);
    $mech->default_header('Accept' => 'application/turtle');
    $mech->get_ok("/foo");
    is($mech->ct, 'text/n3', "Correct content-type");
  TODO: {
        local $TODO = "Should really be a real Turtle syntax";
        is($mech->ct, 'application/turtle', "Correct content-type");
    }
    like($mech->uri, qr|/foo/data$|, "Location is OK");
    $mech->content_contains('This is a test', "Test phrase in content");
}

{
    my $mech = Test::WWW::Mechanize::Mojo->new(tester => $tester, requests_redirectable => []);
    $mech->default_header('Accept' => 'application/rdf+xml');
    my $res = $mech->get("/bar/baz/bing");
    is($mech->status, 303, "Returns 303");
    like($res->header('Location'), qr|/bar/baz/bing/data$|, "Location is OK");
}


{
    my $mech = Test::WWW::Mechanize::Mojo->new(tester => $tester);
    $mech->get_ok("/bar/baz/bing");
    is($mech->ct, 'text/html', "Correct content-type");
    like($mech->uri, qr|/bar/baz/bing/page$|, "Location is OK");
    $mech->title_is('Testing with longer URI.', "Title is correct");
}

{
    my $mech = Test::WWW::Mechanize::Mojo->new(tester => $tester);
    $mech->default_header('Accept' => 'application/rdf+xml');
    $mech->get_ok("/bar/baz/bing");
    is($mech->ct, 'application/rdf+xml', "Correct content-type");
    like($mech->uri, qr|/bar/baz/bing/data$|, "Location is OK");
    $mech->content_contains('Testing with longer URI.', "Test phrase in content");
}



TODO: {
    local $TODO = "We really should return 406 if no acceptable version is there, shouldn't we?";
    my $mech = Test::WWW::Mechanize::Mojo->new(tester => $tester);
    $mech->default_header('Accept' => 'application/foobar');
    my $res = $mech->get("/foo/data");
    is($mech->status, 406, "Returns 406");
}


done_testing();
