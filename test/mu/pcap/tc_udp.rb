# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap'

module Mu
class Pcap
class UDP

class Test < Mu::TestCase
    def test_basics
        udp = UDP.new
        udp.src_port = 0x3039
        udp.dst_port = 0x0050
        udp.payload = 'hello'
        udp.payload_raw = 'hello'
        
        bytes =
            "\x30\x39" + # src port
            "\x00\x50" + # dst port
            "\x00\x0d" + # length
            "\x00\x00" + # checksum
            'hello'
        udp_in = UDP.from_bytes bytes
        assert_equal udp_in, udp
    end
end

end
end
end
