# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap/reader'

module Mu
class Pcap
class Reader

class Test < Mu::TestCase
    class MyReader < Reader
        FAMILY_TO_READER[:my_reader] = self

        def do_read_message! bytes, state
            state[:bytes_recv] ||= 0
            if bytes.size >= 10
                state[:bytes_recv] += 10
                bytes.slice!(0,10)
            end
        end

        def do_record_write bytes, state
            state[:bytes_sent] ||= 0
            state[:bytes_sent] += bytes.size
        end
    end

    def test_basics
        # initialize
        reader = MyReader.new

        # read_message/record_write
        bytes = "a" * 11
        state = {}
        assert_equal "a"*10, reader.read_message(bytes, state)
        assert_equal "a"*11, bytes
        assert_equal "a"*10, reader.read_message!(bytes, state)
        assert_equal "a", bytes
        assert_equal 20, state[:bytes_recv]
        assert_nil reader.read_message('a', state)
        reader.record_write "foo", state
        assert_equal 3, state[:bytes_sent]
        reader.record_write "foo", state
        assert_equal 6, state[:bytes_sent]
    end

    def test_family
        reader = Reader.reader(:my_reader)
        assert_kind_of MyReader, reader
        assert_nil Reader.reader(:none)
        assert_raises(ArgumentError) { Reader.reader(:lkjlkjkl) }
    end

    def test_exception
        reader = MyReader.new
        state = {}
        def reader.do_read_message! bytes, state
            raise "Yikes!"
        end
        def reader.do_record_write bytes, state
            raise "Huh?"
        end

        reader.pcap2scenario = true
        # Return nil instead of raising an exception during pcap2scenario
        assert_nil reader.read_message('a'*10, state)
        assert_nil reader.record_write('a'*10, state)

    end
end

end
end
end
