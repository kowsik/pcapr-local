# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap'

module Mu
class Pcap
class Pkthdr

class Test < Mu::TestCase
    def test_basics
        pkthdr = Pkthdr.new
        pkthdr.endian = LITTLE_ENDIAN
        pkthdr.ts_sec = 1191265036
        pkthdr.ts_usec = 73432
        pkthdr.caplen = 73
        pkthdr.len = 73
        pkthdr.pkt = 'X' * 73

        bytes = "\x0c\x43\x01\x47" + "\xd8\x1e\x01\x00" + 
            "\x49\x00\x00\x00" + "\x49\x00\x00\x00" + ("X" * 73)
        pkthdr_in = Pkthdr.read StringIO.new(bytes), LITTLE_ENDIAN
        assert_equal pkthdr, pkthdr_in
    end
end

end
end
end


