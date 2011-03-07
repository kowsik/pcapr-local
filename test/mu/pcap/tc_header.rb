# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap'

module Mu
class Pcap
class Header

class Test < Mu::TestCase
    def test_basics
        header = Header.new
        header.magic = BIG_ENDIAN
        header.version_major = 2
        header.version_minor = 4
        header.thiszone = 0
        header.sigfigs = 0
        header.snaplen = 1500
        header.linktype = 1

        # Big endian
        bytes = "\xa1\xb2\xc3\xd4" + "\x00\x02" +  "\x00\x04" +
            "\x00\x00\x00\x00" + "\x00\x00\x00\x00" +
            "\x00\x00\x05\xdc" + "\x00\x00\x00\x01"
        header_in = Header.read StringIO.new(bytes)
        assert_equal header, header_in

        # Little endian
        header.magic = LITTLE_ENDIAN
        bytes = "\xd4\xc3\xb2\xa1" + "\x02\x00" +  "\x04\x00" +
            "\x00\x00\x00\x00" + "\x00\x00\x00\x00" +
            "\xdc\x05\x00\x00" + "\x01\x00\x00\x00"
        header_in = Header.read StringIO.new(bytes)
        assert_equal header, header_in
    end


    def test_decode_null
        ethernet = Ethernet.new
        ethernet.src = '00:01:01:00:00:01'
        ethernet.dst = '00:01:01:00:00:02'
        ethernet.type = Ethernet::ETHERTYPE_IP
        ethernet.payload = ethernet.payload_raw = 'hello'
        bytes = nil
        with_no_stderr do # supress warning about malformed IPv4
            bytes = Pkthdr.decode_null BIG_ENDIAN, "\0\0\0\2hello"
        end
        assert_equal ethernet, bytes
    end
end

end
end
end
