# Copyright (c) 2009-2012, Dmitry Vasiliev <dima@hlabs.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#  * Neither the name of the copyright holders nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'test/unit'
require 'erlport/erlterms'

include ErlTerm


class AtomTestCase < Test::Unit::TestCase
    def test_atom
        atom = Atom.new("test")
        assert_equal Atom, atom.class
        assert_equal "test", atom
        assert_equal "X" * 255, Atom.new("X" * 255)
    end

    def test_invalid_atom
        assert_raise(ValueError){Atom.new("X" * 256)}
    end
end

class TupleTestCase < Test::Unit::TestCase
    def test_tuple
        tuple = Tuple.new([1, 2, 3])
        assert_equal Tuple, tuple.class
        assert_equal [1, 2, 3], tuple
    end
end

class ImproperListTestCase < Test::Unit::TestCase
    def test_improper_list
        improper = ImproperList.new [1, 2, 3], "tail"
        assert_equal ImproperList, improper.class
        assert_equal [1, 2, 3], improper
        assert_equal "tail", improper.tail
    end

    def test_improper_list_errors
        assert_raise(TypeError){ImproperList.new([1, 2, 3], ["invalid"])}
        assert_raise(ValueError){ImproperList.new([], "tail")}
    end
end

class DecodeTestCase < Test::Unit::TestCase
    def test_decode
        assert_raise(IncompleteData){decode("")}
        assert_raise(ValueError){decode("\0")}
        assert_raise(IncompleteData){decode("\x83")}
        assert_raise(ValueError){decode("\x83z")}
    end

    def test_decode_atom
        assert_raise(IncompleteData){decode("\x83d")}
        assert_raise(IncompleteData){decode("\x83d\0")}
        assert_raise(IncompleteData){decode("\x83d\0\1")}
        assert_equal Atom, decode("\x83d\0\0")[0].class
        assert_equal [Atom.new(""), ""], decode("\x83d\0\0")
        assert_equal [Atom.new(""), "tail"], decode("\x83d\0\0tail")
        assert_equal [Atom.new("test"), ""], decode("\x83d\0\4test")
        assert_equal [Atom.new("test"), "tail"], decode("\x83d\0\4testtail")
    end

    def test_decode_predefined_atoms
        assert_equal [true, ""], decode("\x83d\0\4true")
        assert_equal [true, "tail"], decode("\x83d\0\4truetail")
        assert_equal [false, ""], decode("\x83d\0\5false")
        assert_equal [false, "tail"], decode("\x83d\0\5falsetail")
        assert_equal [nil, ""], decode("\x83d\0\11undefined")
        assert_equal [nil, "tail"], decode("\x83d\0\11undefinedtail")
    end

    def test_decode_empty_list
        assert_equal [[], ""], decode("\x83j")
        assert_equal [[], "tail"], decode("\x83jtail")
    end

    def test_decode_string_list
        assert_raise(IncompleteData){decode("\x83k")}
        assert_raise(IncompleteData){decode("\x83k\0")}
        assert_raise(IncompleteData){decode("\x83k\0\1")}
        # Erlang use 'j' tag for empty lists
        assert_equal [[], ""], decode("\x83k\0\0")
        assert_equal [[], "tail"], decode("\x83k\0\0tail")
        assert_equal [[116, 101, 115, 116], ""], decode("\x83k\0\4test")
        assert_equal [[116, 101, 115, 116], "tail"],
            decode("\x83k\0\4testtail")
    end

    def test_decode_list
        assert_raise(IncompleteData){decode("\x83l")}
        assert_raise(IncompleteData){decode("\x83l\0")}
        assert_raise(IncompleteData){decode("\x83l\0\0")}
        assert_raise(IncompleteData){decode("\x83l\0\0\0")}
        assert_raise(IncompleteData){decode("\x83l\0\0\0\0")}
        # Erlang use 'j' tag for empty lists
        assert_equal [[], ""], decode("\x83l\0\0\0\0j")
        assert_equal [[], "tail"], decode("\x83l\0\0\0\0jtail")
        assert_equal [[[], []], ""], decode("\x83l\0\0\0\2jjj")
        assert_equal [[[], []], "tail"], decode("\x83l\0\0\0\2jjjtail")
    end

    def test_decode_improper_list
        assert_raise(IncompleteData){decode("\x83l\0\0\0\0k")}
        improper, tail = decode("\x83l\0\0\0\1jd\0\4tail")
        assert_equal ImproperList, improper.class
        assert_equal [[]], improper
        assert_equal Atom, improper.tail.class
        assert_equal Atom.new("tail"), improper.tail
        assert_equal "", tail
        improper, tail = decode("\x83l\0\0\0\1jd\0\4tailtail")
        assert_equal ImproperList, improper.class
        assert_equal [[]], improper
        assert_equal Atom, improper.tail.class
        assert_equal Atom.new("tail"), improper.tail
        assert_equal "tail", tail
    end

    def test_decode_small_tuple
        assert_raise(IncompleteData){decode("\x83h")}
        assert_raise(IncompleteData){decode("\x83h\1")}
        assert_equal Tuple, decode("\x83h\0")[0].class
        assert_equal [Tuple.new([]), ""], decode("\x83h\0")
        assert_equal [Tuple.new([]), "tail"], decode("\x83h\0tail")
        assert_equal [Tuple.new([[], []]), ""], decode("\x83h\2jj")
        assert_equal [Tuple.new([[], []]), "tail"], decode("\x83h\2jjtail")
    end

    def test_decode_large_tuple
        assert_raise(IncompleteData){decode("\x83i")}
        assert_raise(IncompleteData){decode("\x83i\0")}
        assert_raise(IncompleteData){decode("\x83i\0\0")}
        assert_raise(IncompleteData){decode("\x83i\0\0\0")}
        assert_raise(IncompleteData){decode("\x83i\0\0\0\1")}
        # Erlang use 'h' tag for small tuples
        assert_equal [[], ""], decode("\x83i\0\0\0\0")
        assert_equal [[], "tail"], decode("\x83i\0\0\0\0tail")
        assert_equal [[[], []], ""], decode("\x83i\0\0\0\2jj")
        assert_equal [[[], []], "tail"], decode("\x83i\0\0\0\2jjtail")
    end

    def test_decode_opaque_object
        opaque, tail = decode("\x83h\3d\0\x0f$erlport.opaqued\0\10language" \
            "m\0\0\0\4data")
        assert_equal OpaqueObject, opaque.class
        assert_equal "data", opaque.data
        assert_equal "language", opaque.language
        assert_equal "", tail
        opaque, tail = decode("\x83h\3d\0\x0f$erlport.opaqued\0\10language" \
            "m\0\0\0\4datatail")
        assert_equal OpaqueObject, opaque.class
        assert_equal "data", opaque.data
        assert_equal "language", opaque.language
        assert_equal "tail", tail
    end

    def test_decode_ruby_opaque_object
        opaque, tail = decode("\x83h\3d\0\x0f$erlport.opaqued\0\4ruby" \
            "m\0\0\0\10\4\b\"\ttest")
        assert_equal String, opaque.class
        assert_equal "test", opaque
        assert_equal "", tail
        opaque, tail = decode("\x83h\3d\0\x0f$erlport.opaqued\0\4ruby" \
            "m\0\0\0\10\4\b\"\ttesttail")
        assert_equal String, opaque.class
        assert_equal "test", opaque
        assert_equal "tail", tail
    end

    def test_decode_small_integer
        assert_raise(IncompleteData){decode("\x83a")}
        assert_equal [0, ""], decode("\x83a\0")
        assert_equal [0, "tail"], decode("\x83a\0tail")
        assert_equal [255, ""], decode("\x83a\xff")
        assert_equal [255, "tail"], decode("\x83a\xfftail")
    end

    def test_decode_integer
        assert_raise(IncompleteData){decode("\x83b")}
        assert_raise(IncompleteData){decode("\x83b\0")}
        assert_raise(IncompleteData){decode("\x83b\0\0")}
        assert_raise(IncompleteData){decode("\x83b\0\0\0")}
        # Erlang use 'a' tag for small integers
        assert_equal [0, ""], decode("\x83b\0\0\0\0")
        assert_equal [0, "tail"], decode("\x83b\0\0\0\0tail")
        assert_equal [2147483647, ""], decode("\x83b\x7f\xff\xff\xff")
        assert_equal [2147483647, "tail"], decode("\x83b\x7f\xff\xff\xfftail")
        assert_equal [-2147483648, ""], decode("\x83b\x80\0\0\0")
        assert_equal [-2147483648, "tail"], decode("\x83b\x80\0\0\0tail")
        assert_equal [-1, ""], decode("\x83b\xff\xff\xff\xff")
        assert_equal [-1, "tail"], decode("\x83b\xff\xff\xff\xfftail")
    end

    def test_decode_binary
        assert_raise(IncompleteData){decode("\x83m")}
        assert_raise(IncompleteData){decode("\x83m\0")}
        assert_raise(IncompleteData){decode("\x83m\0\0")}
        assert_raise(IncompleteData){decode("\x83m\0\0\0")}
        assert_raise(IncompleteData){decode("\x83m\0\0\0\1")}
        assert_equal ["", ""], decode("\x83m\0\0\0\0")
        assert_equal ["", "tail"], decode("\x83m\0\0\0\0tail")
        assert_equal ["data", ""], decode("\x83m\0\0\0\4data")
        assert_equal ["data", "tail"], decode("\x83m\0\0\0\4datatail")
    end

    def test_decode_float
        assert_raise(IncompleteData){decode("\x83F")}
        assert_raise(IncompleteData){decode("\x83F\0")}
        assert_raise(IncompleteData){decode("\x83F\0\0")}
        assert_raise(IncompleteData){decode("\x83F\0\0\0")}
        assert_raise(IncompleteData){decode("\x83F\0\0\0\0")}
        assert_raise(IncompleteData){decode("\x83F\0\0\0\0\0")}
        assert_raise(IncompleteData){decode("\x83F\0\0\0\0\0\0")}
        assert_raise(IncompleteData){decode("\x83F\0\0\0\0\0\0\0")}
        assert_equal [0.0, ""], decode("\x83F\0\0\0\0\0\0\0\0")
        assert_equal [0.0, "tail"], decode("\x83F\0\0\0\0\0\0\0\0tail")
        assert_equal [1.5, ""], decode("\x83F?\xf8\0\0\0\0\0\0")
        assert_equal [1.5, "tail"], decode("\x83F?\xf8\0\0\0\0\0\0tail")
    end

    def test_decode_small_big_integer
        assert_raise(IncompleteData){decode("\x83n")}
        assert_raise(IncompleteData){decode("\x83n\0")}
        assert_raise(IncompleteData){decode("\x83n\1\0")}
        # Erlang use 'a' tag for small integers
        assert_equal [0, ""], decode("\x83n\0\0")
        assert_equal [0, "tail"], decode("\x83n\0\0tail")
        assert_equal [6618611909121, ""], decode("\x83n\6\0\1\2\3\4\5\6")
        assert_equal [-6618611909121, ""], decode("\x83n\6\1\1\2\3\4\5\6")
        assert_equal [6618611909121, "tail"],
            decode("\x83n\6\0\1\2\3\4\5\6tail")
    end

    def test_decode_big_integer
        assert_raise(IncompleteData){decode("\x83o")}
        assert_raise(IncompleteData){decode("\x83o\0")}
        assert_raise(IncompleteData){decode("\x83o\0\0")}
        assert_raise(IncompleteData){decode("\x83o\0\0\0")}
        assert_raise(IncompleteData){decode("\x83o\0\0\0\0")}
        assert_raise(IncompleteData){decode("\x83o\0\0\0\1\0")}
        # Erlang use 'a' tag for small integers
        assert_equal [0, ""], decode("\x83o\0\0\0\0\0")
        assert_equal [0, "tail"], decode("\x83o\0\0\0\0\0tail")
        assert_equal [6618611909121, ""], decode("\x83o\0\0\0\6\0\1\2\3\4\5\6")
        assert_equal [-6618611909121, ""],
            decode("\x83o\0\0\0\6\1\1\2\3\4\5\6")
        assert_equal [6618611909121, "tail"],
            decode("\x83o\0\0\0\6\0\1\2\3\4\5\6tail")
    end
end