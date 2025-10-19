package Web::Encoding::UnivCharDet::Defs;
use strict;
use warnings;
#our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::Defs;

my $CP949_cls = [
PCK4BITS(    1,1,1,1,1,1,1,1), PCK4BITS(1,1,1,1,1,1,0,0),  # 00 - 0f
PCK4BITS(    1,1,1,1,1,1,1,1), PCK4BITS(1,1,1,0,1,1,1,1),  # 10 - 1f
PCK4BITS(    1,1,1,1,1,1,1,1), PCK4BITS(1,1,1,1,1,1,1,1),  # 20 - 2f
PCK4BITS(    1,1,1,1,1,1,1,1), PCK4BITS(1,1,1,1,1,1,1,1),  # 30 - 3f
PCK4BITS(    1,4,4,4,4,4,4,4), PCK4BITS(4,4,4,4,4,4,4,4),  # 40 - 4f
PCK4BITS(    4,4,5,5,5,5,5,5), PCK4BITS(5,5,5,1,1,1,1,1),  # 50 - 5f
PCK4BITS(    1,5,5,5,5,5,5,5), PCK4BITS(5,5,5,5,5,5,5,5),  # 60 - 6f
PCK4BITS(    5,5,5,5,5,5,5,5), PCK4BITS(5,5,5,1,1,1,1,1),  # 70 - 7f
PCK4BITS(    0,6,6,6,6,6,6,6), PCK4BITS(6,6,6,6,6,6,6,6),  # 80 - 8f
PCK4BITS(    6,6,6,6,6,6,6,6), PCK4BITS(6,6,6,6,6,6,6,6),  # 90 - 9f
PCK4BITS(    6,7,7,7,7,7,7,7), PCK4BITS(7,7,7,7,7,8,8,8),  # a0 - af
PCK4BITS(    7,7,7,7,7,7,7,7), PCK4BITS(7,7,7,7,7,7,7,7),  # b0 - bf
PCK4BITS(    7,7,7,7,7,7,9,2), PCK4BITS(2,3,2,2,2,2,2,2),  # c0 - cf
PCK4BITS(    2,2,2,2,2,2,2,2), PCK4BITS(2,2,2,2,2,2,2,2),  # d0 - df
PCK4BITS(    2,2,2,2,2,2,2,2), PCK4BITS(2,2,2,2,2,2,2,2),  # e0 - ef
PCK4BITS(    2,2,2,2,2,2,2,2), PCK4BITS(2,2,2,2,2,2,2,0),  # f0 - ff
];

my $CP949_st = [
#cls=    0      1      2      3      4      5      6      7      8      9  # previous state =
PCK4BITS(    eError,eStart,     3,eError,eStart,eStart,     4,     5),PCK4BITS(eError,     6, # eStart
    eError,eError,eError,eError,eError,eError),PCK4BITS(eError,eError,eError,eError, # eError
    eItsMe,eItsMe,eItsMe,eItsMe),PCK4BITS(eItsMe,eItsMe,eItsMe,eItsMe,eItsMe,eItsMe, # eItsMe
    eError,eError),PCK4BITS(eStart,eStart,eError,eError,eError,eStart,eStart,eStart), # 3
PCK4BITS(    eError,eError,eStart,eStart,eStart,eStart,eStart,eStart),PCK4BITS(eStart,eStart, # 4
    eError,eStart,eStart,eStart,eStart,eStart),PCK4BITS(eStart,eStart,eStart,eStart, # 5
    eError,eStart,eStart,eStart),PCK4BITS(eStart,eError,eError,eStart,eStart,eStart, # 6
    0,0),                                                                                          
];

my $CP949CharLenTable = [0, 1, 2, 0, 1, 1, 2, 2, 0, 2];

sub CP949SMModel () { +{
  class_table => {
    idxsft => eIdxSft4bits,
    sftmsk => eSftMsk4bits,
    bitsft => eBitSft4bits,
    unitmsk => eUnitMsk4bits,
    data => $CP949_cls,
  },
  class_factor => 10,
  state_table => {
    idxsft => eIdxSft4bits,
    sftmsk => eSftMsk4bits,
    bitsft => eBitSft4bits,
    unitmsk => eUnitMsk4bits,
    data => $CP949_st,
  },
  char_len_table => $CP949CharLenTable,
  name => "euc-kr",
} }

1;

=head1 AUTHOR

Wakaba <wakaba@suikawiki.org>.

=head1 ACKNOWLEDGEMENTS

This module derived from
<https://github.com/sv24-archive/charade/pull/13/files>.

=head1 LICENSE

######################## BEGIN LICENSE BLOCK ########################
# The Original Code is mozilla.org code.
#
# The Initial Developer of the Original Code is
# Netscape Communications Corporation.
# Portions created by the Initial Developer are Copyright (C) 1998
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Wakaba <wakaba@suikawiki.org>
#   Mark Pilgrim - port to Python
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301  USA
######################### END LICENSE BLOCK #########################

=cut
