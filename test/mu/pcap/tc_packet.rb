# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap'

module Mu
class Pcap
class Packet

class Test < Mu::TestCase
    def test_isolate_l7
        # Empty
        assert_equal [], Packet.isolate_l7([])

        # Ethernet
        ethernet = Ethernet.new
        assert_equal [ethernet], Packet.isolate_l7([ethernet])

        # UDP packet
        udp = Ethernet.new
        udp.payload = IPv4.new
        udp.payload.payload = UDP.new
        udp.payload.payload.src_port = 1000
        assert_equal [udp], Packet.isolate_l7([udp])

        # UDP packet and Ethernet
        assert_equal [udp], Packet.isolate_l7([udp, ethernet])
        assert_equal [udp], Packet.isolate_l7([ethernet, udp])

        # UDP packet and DNS
        dns = Ethernet.new
        dns.payload = IPv4.new
        dns.payload.payload = UDP.new
        dns.payload.payload.src_port = 53
        assert_equal [udp], Packet.isolate_l7([udp, dns])
        assert_equal [udp], Packet.isolate_l7([dns, udp])
    end
end

end
end
end
