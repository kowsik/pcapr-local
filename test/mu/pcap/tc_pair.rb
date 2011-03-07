# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap/io_pair'

module Mu
class Pcap
class IOPair
class Test < Mu::TestCase

    def test_stream
        io1, io2 = IOPair.stream_pair

        # send
        assert_equal 3, io1.write("foo")
        assert_equal "foo", io2.read(3)

        # another
        assert_equal 3, io1.write("bar")
        assert_equal "bar", io2.read(0xffff)

        # reverse
        assert_equal 3, io2.write("baz")
        assert_equal "baz", io1.read(0xffff)

        # 2 sends, 1 receive
        assert_equal 3, io1.write("one")
        assert_equal 3, io1.write("two")
        assert_equal "onetwo", io2.read(6)
    end

    def test_packet
        io1, io2 = IOPair.packet_pair

        # send
        assert_equal 3, io1.write("foo")
        assert_equal "foo", io2.read

        # another
        assert_equal 3, io1.write("bar")
        assert_equal "bar", io2.read

        # reverse
        assert_equal 3, io2.write("baz")
        assert_equal "baz", io1.read

        # 2 sends, 2 receives
        assert_equal 3, io1.write("one")
        assert_equal 3, io1.write("two")
        assert_equal "one", io2.read
        assert_equal "two", io2.read
    end
end
end
end
end
