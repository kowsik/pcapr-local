# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap'

module Mu
class Pcap
class Ethernet

class Test < Mu::TestCase
    def test_basics
        ethernet = Ethernet.new
        ethernet.dst = '00:01:01:00:00:02'
        ethernet.src = '00:01:01:00:00:01'
        ethernet.type = 0x1234
        ethernet.payload = ''
        
        bytes = "\0\1\1\0\0\2" + "\0\1\1\0\0\1" + "\x12\x34"
        ethernet_in = Ethernet.from_bytes bytes
        assert_equal ethernet, ethernet_in
    end

    def test_vlan
        ethernet = Ethernet.new
        ethernet.dst = '00:01:01:00:00:02'
        ethernet.src = '00:01:01:00:00:01'
        ethernet.type = 0x1234
        ethernet.payload = 'hi'
        ethernet.payload_raw = 'hi'
        
        # Strip out VLAN tag
        vlan = "\x81\00" + "\x00\x01"
        bytes = "\0\1\1\0\0\2" + "\0\1\1\0\0\1" + vlan + "\x12\x34hi" 
        ethernet_in = Ethernet.from_bytes bytes
        assert_equal ethernet, ethernet_in

        # Strip out multiple VLAN tags
        bytes = "\0\1\1\0\0\2" + "\0\1\1\0\0\1" + vlan*10 + "\x12\x34hi" 
        ethernet_in = Ethernet.from_bytes bytes
        assert_equal ethernet, ethernet_in
    end

    def test_pppoe
        ethernet = Ethernet.new
        ethernet.dst = '00:01:01:00:00:02'
        ethernet.src = '00:01:01:00:00:01'
        ethernet.type = ETHERTYPE_IP
        ethernet.payload = IPv4.new '127.0.0.1', '127.0.0.2'
        ethernet.payload_raw = ethernet.payload.to_bytes

        ipv4 = IPv4.new '127.0.0.1', '127.0.0.2'
        bytes = "\0\1\1\0\0\2" + "\0\1\1\0\0\1" + "\x88\x64" +
            # PPPoE
            "\x11" + # version 1, type 1
            "\x00" + # code
            "\x00\x01" + # session ID
            "\x00\x14" + # length
            # PPP
            "\x00\x21" + # IP
            # IPv4
            ipv4.to_bytes
        ethernet_in = Ethernet.from_bytes bytes
        assert_equal ethernet, ethernet_in
    end
end

end
end
end
