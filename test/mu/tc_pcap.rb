# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap'

module Mu
class Pcap

class Test < Mu::TestCase
    def test_basics
        pcap = Pcap.new
        pkthdr = Pkthdr.new
        pkthdr.caplen = pkthdr.len = 77
        ethernet = Ethernet.new
        ethernet.src = '00:01:01:00:00:01'
        ethernet.dst = '00:01:01:00:00:02'
        ethernet.type = Ethernet::ETHERTYPE_IP
        ethernet.payload = ethernet.payload_raw = 'X' * 73
        pkthdr.pkt = ethernet
        pcap.pkthdrs << pkthdr
        
        bytes = "\xa1\xb2\xc3\xd4" + "\x00\x02" +  "\x00\x04" +
            "\x00\x00\x00\x00" + "\x00\x00\x00\x00" +
            "\x00\x00\x05\xdc" + "\x00\x00\x00\x00" +
            "\x00\x00\x00\x00" + "\x00\x00\x00\x00" + # pkthdr
            "\x00\x00\x00\x4d" + "\x00\x00\x00\x4d" + 
            "\x00\x00\x00\x02" + ("X" * 73)
        pcap_in = nil
        with_no_stderr do # supress warning about malformed IPv4
            pcap_in = Pcap.read StringIO.new(bytes)
        end
        assert_equal pcap_in, pcap
    end
end

end
end
