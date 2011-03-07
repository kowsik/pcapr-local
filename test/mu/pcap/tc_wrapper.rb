# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap/io_wrapper'
require 'mu/pcap/io_pair'

module Mu
class Pcap
class IOWrapper
class Test < Mu::TestCase
    class MessageReader 
        def initialize msg_size=10
            @msg_size = msg_size
        end

        def read_message! bytes, state
            state[:bytes_read] ||= 0
            if bytes.length >= @msg_size
                msg = bytes.slice!(0,@msg_size)
                msg.upcase!
                state[:bytes_read] += @msg_size
            end
            msg
        end

        def record_write bytes, state
            state[:bytes_sent] ||= 0
            state[:bytes_sent] += bytes.size
        end
    end

    def test_basics
        inner, other = IOPair.stream_pair
        wrapped = IOWrapper.new inner, MessageReader.new

        # Reads
        other.write "01234567890123"
        assert_equal "", wrapped.unread
        assert_equal "0123456789", wrapped.read
        assert_equal "0123", wrapped.unread
        assert_equal 10,  wrapped.state[:bytes_read]
        assert_nil wrapped.read
        other.write "456789"
        assert_equal "0123456789", wrapped.read
        assert_equal "", wrapped.unread
        assert_equal 20,  wrapped.state[:bytes_read]
        other.write "abcdefghij"
        assert_equal "ABCDEFGHIJ", wrapped.read
        assert_equal 30,  wrapped.state[:bytes_read]

        # Writes
        wrapped.write "hi mom"
        assert_equal 6, wrapped.state[:bytes_sent]
        assert_equal "hi mom", other.read
        assert_equal "", other.read
    end

    def test_too_big_receive
        # Message at max size.
        inner, other = IOPair.stream_pair
        wrapped = IOWrapper.new inner, MessageReader.new(MAX_RECEIVE_SIZE + 2)
        big = "a" * MAX_RECEIVE_SIZE
        other.write big
        wrapped.read

        # Message over max size.
        too_big = big + "1"
        other.write too_big
        e = assert_raises(RuntimeError) do
            wrapped.read
        end
        assert_match "Maximum message size (#{MAX_RECEIVE_SIZE}) exceeded", e.message
    end

end
end
end
end
