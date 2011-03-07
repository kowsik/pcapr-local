# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap'

module Mu
class Pcap
class IPv6

class Test < Mu::TestCase
    def test_basics
        bytes =
            "60000000"                         + # version, class, label
            "0005"                             + # length
            "59"                               + # next header
            "40"                               + # hop limit
            "00000000000000000000000000000001" + # source
            "ff020000000000000000000000000005"   # destination
        bytes = bytes.from_hex + 'hello'

        ipv6 = IPv6.new
        ipv6.next_header = 0x59
        ipv6.hop_limit = 64
        ipv6.src = '::1'
        ipv6.dst = 'ff02::5'
        ipv6.payload = 'hello'
        ipv6.payload_raw = 'hello'

        ipv6_in = nil
        with_no_stderr do # supress warning about options
            ipv6_in = IPv6.from_bytes bytes
        end
        assert_equal ipv6, ipv6_in
    end

    def test_headers
        packet =
            "60000000"                         + # version, class, label
            "%04x"                             + # length
            "%02x"                             + # next header
            "40"                               + # hop limit
            "00000000000000000000000000000001" + # source
            "ff020000000000000000000000000005"   # destination

        # No next header
        bytes = (packet % [0, IP::IPPROTO_NONE]).from_hex
        ipv6 = IPv6.from_bytes bytes
        assert_equal IP::IPPROTO_NONE, ipv6.next_header
        assert_equal '', ipv6.payload

        # Hop-by-hop options
        bytes = (packet % [8, IP::IPPROTO_HOPOPTS]).from_hex +
            [IP::IPPROTO_NONE, 0, "\0\0\0\0\0\0"].pack('CCa6')
        ipv6 = IPv6.from_bytes bytes
        assert_equal IP::IPPROTO_NONE, ipv6.next_header

        # Routing header options
        bytes = (packet % [8, IP::IPPROTO_ROUTING]).from_hex +
            [IP::IPPROTO_NONE, 0, "\0\0\0\0\0\0"].pack('CCa6')
        ipv6 = IPv6.from_bytes bytes
        assert_equal IP::IPPROTO_NONE, ipv6.next_header

        # Destination options
        bytes = (packet % [8, IP::IPPROTO_DSTOPTS]).from_hex +
            [IP::IPPROTO_NONE, 0, "\0\0\0\0\0\0"].pack('CCa6')
        ipv6 = IPv6.from_bytes bytes
        assert_equal IP::IPPROTO_NONE, ipv6.next_header

        # Fragment (not supported)
        bytes = (packet % [8, IP::IPPROTO_FRAGMENT]).from_hex +
            [IP::IPPROTO_NONE, 0, 0, 0].pack('CCnN')
        with_no_stderr do
            ipv6 = IPv6.from_bytes bytes
        end
        assert_equal IP::IPPROTO_FRAGMENT, ipv6.next_header
    end
end

end
end
end
