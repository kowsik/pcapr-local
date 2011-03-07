# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap'

module Mu
class Pcap
class TCP

class Test < Mu::TestCase
    def test_basics
        tcp = TCP.new
        tcp.src_port = 0x3039
        tcp.dst_port = 0x0050
        tcp.flags = 2
        tcp.seq = 0
        tcp.ack = 0
        tcp.window = 0x3de0
        tcp.urgent = 0
        tcp.payload = 'hello'
        tcp.payload_raw = 'hello'
        
        bytes =
            "\x30\x39" +           # src port
            "\x00\x50" +           # dst port
            "\x00\x00\x00\x00" +   # seq
            "\x00\x00\x00\x00" +   # dst
            "\x50" +               # offset
            "\x02" +               # flags
            "\x3d\xe0" +           # window
            "\x00\x00" +           # checksum
            "\x00\x00" +           # urp
            'hello'
        tcp_in = TCP.from_bytes bytes
        assert_equal tcp_in, tcp
    end

    def test_reorder
        # empty stream
        assert_equal [], TCP.reorder([])

        # one flow
        tcp = tcp(:client, 'hello')
        assert_equal [tcp], TCP.reorder([tcp])

        # different flows
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:server, 'hello')
        assert_equal [tcp1, tcp2], TCP.reorder([tcp1, tcp2])

        # hello, world
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:client, 'world', 5)
        assert_equal [tcp1, tcp2], TCP.reorder([tcp1, tcp2])

        # world, discard old hello
        tcp1 = tcp(:client, 'world', 5)
        tcp2 = tcp(:client, 'hello')
        assert_equal [tcp1], TCP.reorder([tcp1, tcp2])

        # discard duplicate
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:client, 'hello')
        assert_equal [tcp1], TCP.reorder([tcp1, tcp2])

        # overlap
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:client, 'oworld', 4)
        TCP.reorder [tcp1, tcp2]

        # out of order packets
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:client, 'ld', 8)
        tcp3 = tcp(:client, 'wor', 5)
        assert_equal [tcp1, tcp3, tcp2], TCP.reorder([tcp1, tcp2, tcp3])

        # out of order packets
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:client, 'wor', 5)
        tcp3 = tcp(:client, 'l', 8)
        tcp4 = tcp(:client, 'd', 9)
        [[tcp2, tcp3, tcp4],
         [tcp2, tcp4, tcp3],
         [tcp3, tcp2, tcp4], 
         [tcp3, tcp4, tcp2], 
         [tcp4, tcp2, tcp3], 
         [tcp4, tcp3, tcp2]].each do |tcps|
            assert_equal [tcp1, tcp2, tcp3, tcp4],
                TCP.reorder([tcp1, *tcps])
        end

        # unfilled gap
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:client, 'world', 6)
        assert_raises ReorderError do
            TCP.reorder [tcp1, tcp2]
        end

        # syn
        tcp1 = tcp(:client, '', 0, TCP::TH_SYN)
        tcp2 = tcp(:client, 'hello', 1)
        assert_equal [tcp1, tcp2], TCP.reorder([tcp1, tcp2])

        # wrap sequence number
        tcp1 = tcp(:client, 'hello', 2**32 - 1)
        tcp2 = tcp(:client, 'world', 4)
        assert_equal [tcp1, tcp2], TCP.reorder([tcp1, tcp2])
    end

    def test_merge
        assert_equal [], TCP.merge([])
        
        # Ethernet
        ethernet = Ethernet.new
        assert_equal [ethernet], TCP.merge([ethernet])

        # IPv4
        ipv4 = IPv4.new
        ipv4.src = '10.0.0.1'
        ipv4.dst = '10.0.0.2'
        ipv4.proto = IPv4::IPPROTO_TCP
        ethernet = Ethernet.new
        ethernet.type = Ethernet::ETHERTYPE_IP
        ethernet.payload = ipv4
        assert_equal [ethernet], TCP.merge([ethernet])

        # TCP, no data
        tcp = tcp(:client, '')
        assert_equal [], TCP.merge([tcp])

        # TCP
        tcp = tcp(:client, 'hello')
        assert_equal [tcp], TCP.merge([tcp])

        # Two TCP in different directions
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:server, 'world')
        assert_equal [tcp1, tcp2], TCP.merge([tcp1, tcp2])

        # Basic merge (original payloads not modified)
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:client, 'world', 5)
        tcp3 = tcp(:client, 'three', 10)
        tcp = tcp(:client, 'helloworldthree')
        assert_equal [tcp], TCP.merge([tcp1, tcp2, tcp3])
        assert_equal 'hello', tcp1.payload.payload.payload
        assert_equal 'world', tcp2.payload.payload.payload

        # overlap - favor second packet
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:client, 'Xworld', 4)
        tcp3 = tcp(:client, 'three', 10)
        tcp = tcp(:client, 'helloworldthree')
        assert_equal [tcp], TCP.merge([tcp1, tcp2, tcp3])

        # gap - raise error
        tcp1 = tcp(:client, 'hello')
        tcp2 = tcp(:client, 'world', 6)
        assert_raises MergeError do
            TCP.merge([tcp1, tcp2])
        end

        # sequence number wrap
        tcp1 = tcp(:client, 'hello', 2**32 - 1)
        tcp2 = tcp(:client, 'world', 4)
        tcp = tcp(:client, 'helloworld', 2**32 - 1)
        assert_equal [tcp], TCP.merge([tcp1, tcp2])

        # sequence number wrap with overlap
        tcp1 = tcp(:client, 'hello', 2**32 - 1)
        tcp2 = tcp(:client, 'Xworld', 3)
        tcp = tcp(:client, 'helloworld', 2**32 - 1)
        assert_equal [tcp], TCP.merge([tcp1, tcp2])
    end

    def http_wrap bytes
        "GET / HTTP/1.1\r\n" +
        "some-header: foo\r\n" +
        "some-length: 34\r\n" +
        "Content-Length: #{bytes.length}\r\n" +
        "Content-Something: baz\r\n" +
        "\r\n" +
        bytes
    end

    def make_stream bytes, direction, connection=1, offset=0, seg_size=1
        io = StringIO.new bytes
        packets = []
        while bytes = io.read(seg_size)
            packets << tcp(direction, bytes, offset, 0, connection)
            offset += bytes.length
        end
        packets
    end

    TCP_FLAGS = 0
    def test_message_assembly
        message_1 = http_wrap("0123456789" * 100).freeze
        message_2 = http_wrap("abcdefghij" * 100).freeze
        message_3 = http_wrap("ABCDEFGHIJ" * 100).freeze
 
        # Reassemble segments into message
        packets = make_stream message_1, :client, 1
        assert_equal [tcp(:client, message_1)], TCP.merge(packets)
        
        # Insert server packet in front (should have no effect)
        packets = make_stream message_1, :client, 1
        server_packet = tcp(:server, "bytes")
        packets.unshift server_packet
        expect = [
            server_packet,
            tcp(:client, message_1, 0, TCP_FLAGS, 1)
        ]
        assert_equal expect, TCP.merge(packets)

        # One interleaved packet from a different connection.
        #  HTTP message should be reassembled and appear second.
        packets = make_stream message_1, :client, 1
        extra_packet = tcp(:server, "X"*40, 0, TCP_FLAGS, 3)
        packets[packets.length/2, 0] = [extra_packet]
        expect = [
            extra_packet,
            tcp(:client, message_1, 0, TCP_FLAGS, 1)
        ]
        assert_equal expect, TCP.merge(packets)

        # Two messages in a row with one interleaved packet 
        #  from a different connection in middle of first message
        #
        # The first message should be ressambled after the extra packet.
        packets = make_stream message_1 + message_2, :client, 1
        extra_packet = tcp(:server, "XXXXXX", 0, TCP_FLAGS, 3)
        packets[packets.length/4, 0] = [extra_packet]
        expect = [
            extra_packet,
            tcp(:client, message_1, 0, TCP_FLAGS, 1),
            tcp(:client, message_2, message_1.length, TCP_FLAGS, 1),
        ]
        assert_equal expect, TCP.merge(packets) # wrong?
        
        # Two messages in a row with one interleaved packet 
        #  from a different connection in middle of second message
        # The second message should be reassembled after the
        # extra packet.
        packets = make_stream message_1 + message_2, :client, 1
        extra_packet = tcp(:server, "bytes", 0, TCP_FLAGS, 3)
        packets[(packets.length*0.75).to_i, 0] = [extra_packet]
        expect = [
            tcp(:client, message_1, 0, TCP_FLAGS, 1),
            extra_packet,
            tcp(:client, message_2, message_1.length, TCP_FLAGS, 1),
        ]
        assert_equal expect, TCP.merge(packets)
        
        # Http message, followed by non http message with interleaved
        # packet. Packets should not be merged or split because one 
        # of the flows has an incomplete message.
        part1 = message_1
        part2 = "X"*50
        part3 = "Z"*50
        message_bytes = part1 + part2 + part3
        packets = make_stream message_bytes, :client, 1
        extra_packet = tcp(:server, "EXTRA", 0, TCP_FLAGS, 3)
        packets[-50, 0] = [extra_packet]
        seq = 0
        expect = [
            tcp(:client, part1+part2, seq, TCP_FLAGS, 1),
            extra_packet,
            tcp(:client, part3, (part1.size + part2.size), TCP_FLAGS, 1),
        ]
        assert_equal expect, TCP.merge(packets)
        
        # 3 Messages with interleaved packets from a different connection 
        # in the middle of the 2nd message and between the 2nd and 3rd
        # messages.
        packets = make_stream message_1 + message_2, :client, 1
        extra_packet_1 = tcp(:client, "request", 0, TCP_FLAGS, 3)
        packets[-packets.length/4, 0] = [extra_packet_1]
        extra_packet_2 = tcp(:client, "request2", 0, TCP_FLAGS, 4)
        packets << extra_packet_2
        packets.concat  make_stream(message_3, :client, 1, (message_1 + message_2).size)
        seq = 0
        expect = [ 
            tcp(:client, message_1, seq, TCP_FLAGS, 1),
            extra_packet_1,
            tcp(:client, message_2, seq+=message_1.size, TCP_FLAGS, 1),
            extra_packet_2,
            tcp(:client, message_3, seq+=message_2.size, TCP_FLAGS, 1), 
        ]
        assert_equal expect, TCP.merge(packets)
        
        # One interleaved packet from server side of same connection, 
        #  message should  be reassembled.
        packets = make_stream message_1, :client, 1
        part1 = TCP.merge(packets[0...packets.length/2])
        part2 = TCP.merge(packets[packets.length/2..-1])
        extra_packet = tcp(:server, message_2, 0, TCP_FLAGS, 1)
        packets = [part1, extra_packet, part2].flatten
        expect = [
            extra_packet,
            tcp(:client, message_1, 0, TCP_FLAGS, 1),
        ]
        assert_equal expect, TCP.merge(packets)

        # Alternate packets from different connections, messages should be assembled.
        stream_1 = make_stream message_1, :client, 1
        stream_2 = make_stream message_2, :server, 2
        packets = stream_1.zip(stream_2).flatten
        expect = [
            tcp(:client, message_1, 0, TCP_FLAGS, 1),
            tcp(:server, message_2, 0, TCP_FLAGS, 2)
        ]
        assert_equal expect, TCP.merge(packets)
        
        # Switch first packet
        stream_1 = make_stream message_1, :client, 1
        stream_2 = make_stream message_2, :server, 2
        packets = stream_2.zip(stream_1).flatten
        expect = [
            tcp(:server, message_2, 0, TCP_FLAGS, 2), 
            tcp(:client, message_1, 0, TCP_FLAGS, 1)
        ]
        assert_equal expect, TCP.merge(packets)
        
        # Alternate packets from different sides of same connection, 
        #  messages should be reassmbled.
        stream_1 = make_stream message_1, :client, 1
        stream_2 = make_stream message_2, :server, 1
        packets = stream_1.zip(stream_2).flatten
        stream_1 = make_stream message_1, :client, 1
        stream_2 = make_stream message_2, :server, 1
        expect = [
            tcp(:client, message_1, 0, TCP_FLAGS, 1),
            tcp(:server, message_2, 0, TCP_FLAGS, 1), 
        ]
        assert_equal expect, TCP.merge(packets)

        # Messages should not be merged because they
        # are too big and would need to be split into
        # 64K chunks.
        part_2 = http_wrap("Z" * 80 * 1024)
        part_1 = part_2.slice!(0,70*1024)
        packets = [
            tcp(:client, part_1, 0, TCP_FLAGS),
            tcp(:server, message_2, 0, TCP_FLAGS),
            tcp(:client, part_2, 0, TCP_FLAGS),
        ]
        expect = [
            tcp(:client, part_1, 0, TCP_FLAGS),
            tcp(:server, message_2, 0, TCP_FLAGS),
            tcp(:client, part_2, 0, TCP_FLAGS),
        ]
        assert_equal expect, TCP.merge(packets)
    end

    def test_split
        assert_equal [], TCP.split([])

        tcp = tcp(:client, 'A' * (65535 - 54))
        assert_equal [tcp], TCP.split([tcp])

        tcp = tcp(:client, 'A' * 65535)
        tcp1 = tcp(:client, 'A' * (65535 - 54))
        tcp2 = tcp(:client, 'A' * 54, (65535 - 54))
        assert_equal [tcp1, tcp2], TCP.split([tcp])
    end

    def test_tcp_seq_sub
        assert_equal 1, TCP.seq_sub(2, 1)
        assert_equal 0, TCP.seq_sub(1, 1)
        assert_equal 1, TCP.seq_sub(0, 2**32-1)
        assert_equal(-1, TCP.seq_sub(2**32-1, 0))
        assert_equal 0, TCP.seq_sub(2**32-1, 2**32-1)

        assert TCP.seq_eq(0, 0)
        assert TCP.seq_eq(2**32, 0)
        assert TCP.seq_eq(0, 2**32)

        assert TCP.seq_lt(1, 2)
        assert !TCP.seq_lt(2, 1)
        assert !TCP.seq_lt(2, 2)
        assert TCP.seq_lt(2**32-1, 0)
        assert !TCP.seq_lt(0, 2**32-1)

        assert TCP.seq_lte(1, 2)
        assert !TCP.seq_lte(2, 1)
        assert TCP.seq_lte(2, 2)
        assert TCP.seq_lt(2**32-1, 0)
        assert !TCP.seq_lt(0, 2**32-1)
    end

    def tcp sender, payload, seq=0, flags=0, connection=1
        tcp = TCP.new
        ipv4 = IPv4.new
        ethernet = Ethernet.new
        if sender == :client
            ethernet.src = '00:01:00:00:00:01'
            ethernet.dst = '00:01:00:00:00:02'
            ipv4.src = '10.0.0.1'
            ipv4.dst = '10.0.0.2'
            tcp.src_port = connection 
            tcp.dst_port = connection + 10000
        else
            ethernet.src = '00:01:00:00:00:02'
            ethernet.dst = '00:01:00:00:00:01'
            ipv4.src = '10.0.0.2'
            ipv4.dst = '10.0.0.1'
            tcp.src_port = connection + 10000
            tcp.dst_port = connection
        end
        tcp.flags = flags
        tcp.seq = seq
        tcp.payload = payload
        ipv4.proto = IPv4::IPPROTO_TCP
        ipv4.payload = tcp
        ethernet.type = Ethernet::ETHERTYPE_IP
        ethernet.payload = ipv4
        return ethernet
    end
end

end
end
end
