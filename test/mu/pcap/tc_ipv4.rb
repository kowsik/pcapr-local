# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap'

module Mu
class Pcap
class IPv4

class Test < Mu::TestCase
    def test_basics
        bytes = 
            "\x47"+                    # version, header length
            "\x00" +                   # TOS
            "\x00\x1c" +               # length
            "\x4c\xb7" +               # ID
            "\x00\x00" +               # offset
            "\x40" +                   # TTL
            "\x01" +                   # protocol
            "\x99\x2a" +               # checksum
            "\x0a\x01\x02\x03" +       # src-ip
            "\x0a\x02\x03\x04" +       # dst-ip
            "\x94\x04\x00\x00\x00\x00" + "\x00\x00" # options

        ipv4 = IPv4.new
        ipv4.ip_id = 19639
        ipv4.ttl = 64
        ipv4.proto = 1
        ipv4.src = '10.1.2.3'
        ipv4.dst = '10.2.3.4'
        ipv4.payload = ''

        ipv4_in = nil
        with_no_stderr do # supress warning about options
            ipv4_in = IPv4.from_bytes bytes
        end
        assert_equal ipv4, ipv4_in
    end

    def test_reassemble
        # empty stream
        assert_equal [], IPv4.reassemble([])

        # one packet
        ip = ip 0, "A" * 10
        assert_equal [ip], IPv4.reassemble([ip])

        # three packets
        ip1 = ip IP_MF | 0, "A" * 16
        ip2 = ip IP_MF | 2, "B" * 16
        ip3 = ip         4, "C" * 16
        ipo = ip IP_MF | 3, "B" * 8 + "C" * 8 # overlap
        ipe = ip IP_MF | 1,  ""                # empty
        ip  = ip         0, "A" * 16 + "B" * 16 + "C" * 16
        [[ip1, ip2, ip3],
         [ip1, ip3, ip2],
         [ip2, ip1, ip3],
         [ip2, ip3, ip1],
         [ip3, ip1, ip2],
         [ip3, ip2, ip1]].each do |ips|
            with_no_stderr do
                assert_equal [ip], IPv4.reassemble(ips)
            end
            # test with overlapping fragment
            0.upto(ips.length-1) do |i|
                ips.insert i, ipo
                with_no_stderr do
                    assert_equal [ip], IPv4.reassemble(ips)
                end
                ips.delete_at i
            end
            # test with empty fragment
            0.upto(ips.length-1) do |i|
                ips.insert i, ipe
                with_no_stderr do
                    assert_equal [ip], IPv4.reassemble(ips)
                end
                ips.delete_at i
            end
        end
    end

    def ip offset, payload
        ipv4 = IPv4.new
        ethernet = Ethernet.new
        ethernet.src = '00:01:00:00:00:01'
        ethernet.dst = '00:01:00:00:00:02'
        ipv4.src = '10.0.0.1'
        ipv4.dst = '10.0.0.2'
        ipv4.proto = IPv4::IPPROTO_TCP
        ipv4.offset = offset
        ipv4.payload = payload
        ethernet.type = Ethernet::ETHERTYPE_IP
        ethernet.payload = ipv4
        return ethernet
    end
end

end
end
end
