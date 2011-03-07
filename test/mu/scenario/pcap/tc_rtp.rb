# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/scenario/pcap/rtp'

module Mu
class Scenario
module Pcap
module Rtp

class Test < Mu::TestCase

    DATA = [
        [[:udp, 1,2,3,4], {}],
        [[:udp, 3,4,5,6], {:"rtp.setup-frame" => 1}]
    ]

    Packet = ::Struct.new :flow_id
    def gen_packets data
        packets = [] 
        fields_array = []
        data.map do |flow_id, fields|
            packets << Packet.new(flow_id)
            fields_array << fields
        end
        return packets, fields_array
    end

    def test_preprocess
        trunc_count_save = Rtp::TRUNC_COUNT
        Rtp.const_set! :TRUNC_COUNT, 5
        # No truncation
        packets, fields = gen_packets [
            [[:udp, 1,2,3,4], {}],
            [[:udp, 3,4,5,6], {:"rtp.setup-frame" => 1}],
            [[:udp, 3,4,5,6], {:"rtp.setup-frame" => 1}],
            [[:udp, 3,4,5,6], {:"rtp.setup-frame" => 1}],
            [[:udp, 3,4,5,6], {:"rtp.setup-frame" => 1}],
            [[:udp, 3,4,5,6], {:"rtp.setup-frame" => 1}],
        ]
        filter = Rtp.preprocess packets, fields
        assert_equal 6, packets.length
        assert_equal "not rtp", filter

        # Truncate stream
        packets, fields = gen_packets [
            [[:udp, 1,2,3,4], {}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}], #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}], #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}], #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}], #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}], #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}], #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}], #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}], #skip
        ]
        filter = Rtp.preprocess packets, fields
        assert_equal TRUNC_COUNT + 1, packets.length
        assert_equal TRUNC_COUNT + 1, fields.length
        assert_equal "not rtp or frame.number == 2 or frame.number == 3 or frame.number == 4 or frame.number == 5 or frame.number == 6", filter

        # Updated signaling resets truncation counter
        packets, fields = gen_packets [
            [[:udp, 1,2,3,4], {}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}], #skip

            [[:udp, 1,2,3,4], {}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "8"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "8"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "8"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "8"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "8"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "8"}], #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "8"}], #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "8"}], #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "8"}], #skip
        ]
        filter = Rtp.preprocess packets, fields
        assert_equal TRUNC_COUNT*2 + 2, packets.length
        assert_equal TRUNC_COUNT*2 + 2, fields.length
        assert_equal "not rtp or frame.number == 2 or frame.number == 3 or frame.number == 4 or frame.number == 5 or frame.number == 6 or frame.number == 9 or frame.number == 10 or frame.number == 11 or frame.number == 12 or frame.number == 13", filter

        # Missing signaling (e.g. rtp not fully dissected) can be filled in. 
        packets, fields = gen_packets [
            [[:udp, 1,2,3,4], {}],
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}],
            [[:udp, 3,4,5,6], {:rtp => "rtp"}],  
            [[:udp, 3,4,5,6], {:rtp => "rtp"}],  
            [[:udp, 3,4,5,6], {:rtp => "rtp"}],  
            [[:udp, 3,4,5,6], {:rtp => "rtp"}],  
            [[:udp, 3,4,5,6], {:rtp => "rtp"}], # skip
            [[:udp, 3,4,5,6], {:rtp => "rtp"}], # skip
            [[:udp, 3,4,5,6], {:rtp => "rtp"}], # skip
        ]
        filter = Rtp.preprocess packets, fields
        assert_equal TRUNC_COUNT + 1, packets.length
        assert_equal TRUNC_COUNT + 1, fields.length
        assert_equal "not rtp or frame.number == 2 or frame.number == 3 or frame.number == 4 or frame.number == 5 or frame.number == 6", filter


        # We don't bother trying to fill in missing signaling for
        # first packets in stream. Just skip it.
        packets, fields = gen_packets [
            [[:udp, 1,2,3,4], {}],
            [[:udp, 3,4,5,6], {:rtp => "rtp"}],   #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp"}],   #skip
            [[:udp, 3,4,5,6], {:rtp => "rtp", :"rtp.setup-frame" => "1"}], # keep
            [[:udp, 3,4,5,6], {:rtp => "rtp"}],   # keep 
            [[:udp, 3,4,5,6], {:rtp => "rtp"}],   # keep 
        ]
        filter = Rtp.preprocess packets, fields
        assert_equal 4, packets.length
        assert_equal 4, fields.length
        assert_equal "not rtp or frame.number == 4 or frame.number == 5 or frame.number == 6", filter
    ensure
        Rtp.const_set! :TRUNC_COUNT, trunc_count_save if trunc_count_save
    end
end

end
end
end
end
