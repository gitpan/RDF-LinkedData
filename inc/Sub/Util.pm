#line 1
# Copyright (c) 2014 Paul Evans <leonerd@leonerd.org.uk>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Sub::Util;

use strict;
use warnings;

require Exporter;
require List::Util; # as it has the XS

our @ISA = qw( Exporter );
our @EXPORT_OK = qw(
  prototype set_prototype
  subname set_subname
);

our $VERSION    = "1.40";
$VERSION   = eval $VERSION;

#line 40

#line 44

#line 54

sub prototype
{
  my ( $code ) = @_;
  return CORE::prototype( $code );
}

#line 83

#line 109

#line 135

#line 145

1;
