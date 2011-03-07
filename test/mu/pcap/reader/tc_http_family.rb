# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/pcap/reader/http_family'
require 'mu/pcap/io_pair'
require 'mu/pcap/io_wrapper'

module Mu
class Pcap
class Reader
class HttpFamily

class Test < Mu::TestCase

    def test_family
        reader = HttpFamily.new
        assert_equal :http, reader.family
    end

    def test_record_write
        reader = HttpFamily.new
        assert_nil reader.record_write('')

        state = {}
        reader.record_write '', state
        assert_equal({}, state)

        bytes = "GET /admin/ HTTP/1.1\r\n" \
                "Content-Length: 0\r\n" \
                "User-Agent: Jakarta Commons-HttpClient/3.1\r\n" \
                "Host: dell-7.musecurity.com\r\n" \
                "\r\n"
        reader.record_write bytes, state
        assert_equal({:requests => ['GET']}, state)
        reader.record_write bytes, state
        assert_equal({:requests => ['GET', 'GET']}, state)
        reader.record_write bytes.gsub('GET', 'POST'), state
        assert_equal({:requests => ['GET', 'GET', 'POST']}, state)
    end


    def test_reader
        # Msg no body.
        reader = HttpFamily.new
        reader.pcap2scenario = true 
        bytes = "GET /admin/ HTTP/1.1\r\n" \
                "Content-Length: 0\r\n" \
                "User-Agent: Jakarta Commons-HttpClient/3.1\r\n" \
                "Host: dell-7.musecurity.com\r\n" \
                "\r\n"
        assert_equal bytes, reader.read_message(bytes)

        # Don't include incomplete message
        assert_equal bytes, reader.read_message(bytes + "extra")

        # Empty message
        assert_nil reader.read_message("")

        # Incomplete/invalid message
        assert_nil reader.read_message("lkjkljlkj")

        # Incomplete message. Last byte missing.
        bytes = "GET /admin/ HTTP/1.1\r\n" \
                "Content-Length: 0\r\n" \
                "User-Agent: Jakarta Commons-HttpClient/3.1\r\n" \
                "Host: dell-7.musecurity.com\r\n" \
                "\r" 
        assert_nil reader.read_message(bytes)

        # Invalid message. No request line.
        bytes = "XXXXXXXXXXXXXXXXXXXX\r\n" + # no request line
                "Content-Length: 0\r\n" \
                "User-Agent: Jakarta Commons-HttpClient/3.1\r\n" \
                "Host: dell-7.musecurity.com\r\n" \
                "\r\n"
        assert_nil reader.read_message(bytes)

        # Lowercase content-length.
        bytes = "GET /admin/ HTTP/1.1\r\n" \
                "content-length: 0\r\n" \
                "User-Agent: Jakarta Commons-HttpClient/3.1\r\n" \
                "Host: dell-7.musecurity.com\r\n" \
                "\r\n"
        assert_equal bytes, reader.read_message(bytes)

        # In RFC, if there is a payload and no content-length header then
        # you should read  until the connection is close. 
        # We don't handle this and just treat it as a message with no body.
        bytes = "POST /admin/ HTTP/1.1\r\n" \
                "User-Agent: Jakarta Commons-HttpClient/3.1\r\n" \
                "Host: dell-7.musecurity.com\r\n" \
                "\r\n1"

        assert_equal bytes[0..-2], reader.read_message(bytes)
        #reader.read_message!(bytes)
        reader.read_message!(bytes)
        assert_equal "1", bytes

        # 1 byte payload.
        bytes = "GET /admin/ SIP/1.1\r\n" \
                "content-length: 1\r\n" \
                "User-Agent: Jakarta Commons-HttpClient/3.1\r\n" \
                "Host: dell-7.musecurity.com\r\n" \
                "\r\n1"
        assert_equal bytes, reader.read_message(bytes)

        # Support for SIP compact form of content-length
        bytes = "GET /admin/ SIP/1.1\r\n" \
                "l: 1\r\n" + # content-length
                "User-Agent: Jakarta Commons-HttpClient/3.1\r\n" \
                "Host: dell-7.musecurity.com\r\n" \
                "\r\n1"
        assert_equal bytes, reader.read_message(bytes.dup)

        # SIP compact form should only be recognized for SIP.
        bytes = "GET /admin/ HTTP/1.1\r\n" \
                "l: 1\r\n" + # http doesn't have short form
                "User-Agent: Jakarta Commons-HttpClient/3.1\r\n" \
                "Host: dell-7.musecurity.com\r\n" \
                "\r\n1" # so this extra byte will not be read
        copy = bytes.dup
        assert_equal bytes[0..-2], reader.read_message!(copy)
        assert_equal "1", copy

        
        # Reply to HEAD request
        bytes = <<-HERE
HTTP/1.1 200 OK\r
Content-Encoding: gzip\r
Content-Length: 3\r
Keep-Alive: timeout=15, max=100\r
Connection: Keep-Alive\r
Content-Type: text/html\r
\r
        HERE
        assert_equal bytes, reader.read_message(bytes + "123", {:requests => ["HEAD"]})

        # Chunked
        bytes = <<-HERE
HTTP/1.1 200 OK\r
Transfer-Encoding: chunked\r
Content-Type: text/html\r
\r
        HERE
        # chunk1
        bytes << "5\r\n"
        bytes << "A"*5   
        bytes << "\r\n"
        bytes << "3\r\n"
        bytes << "B" * 3
        bytes << "\r\n"
        bytes << "0\r\n\r\n"
        assert_equal bytes, reader.read_message(bytes)

        # Chunked (incomplete)
        bytes = <<-HERE
HTTP/1.1 200 OK\r
Transfer-Encoding: chunked\r
Content-Type: text/html\r
\r
        HERE
        # chunk1
        bytes << "5\r\n"
        bytes << "A"*5
        bytes << "3\r\n"
        bytes << "B" * 3
        assert_nil reader.read_message(bytes)

    end

    def client_server_pair
        IOPair.stream_pair.map do |io| 
            reader = HttpFamily.new 
            reader.pcap2scenario = true
            IOWrapper.new io, reader
        end
    end

    def test_get_chunks
        reader = HttpFamily.new 
        # Chunks 
        raw_bytes       = "5\r\nAAAAA\r\n3\r\nBBB\r\n0\r\n\r\n"
        dechunked_bytes = "AAAAABBB"
        
        raw, dechunked = reader.get_chunks(raw_bytes)
        assert_equal raw_bytes, raw
        assert_equal dechunked_bytes, dechunked

        # Missing final CRLF
        raw_bytes = "5\r\nAAAAA\r\n3\r\nBBB\r\n0\r\n"
        dechunked_bytes = "AAAAABBB"
        assert_nil reader.get_chunks(raw_bytes)

        # Missing end of chunks
        raw_bytes = "5\r\nAAAAA\r\n3\r\nBBB\r\n"
        assert_nil reader.get_chunks(raw_bytes)
        
        # Malformed chunk size line
        raw_bytes = "5\r\nAAAAA3\r\nBBB0foo\r\n"
        assert_nil reader.get_chunks(raw_bytes)

        # Second chunk missing a byte
        raw_bytes = "5\r\nAAAAA3\r\nBB0\r\n\r\n"
        assert_nil reader.get_chunks(raw_bytes)
    end

    def test_transaction_mult_requests
        # Client sends 3 requests GET/HEAD/GET and then gets 3 replies
        client,server = client_server_pair
        client.write "GET /admin/ HTTP/1.1\r\n\r\n"
        assert_equal ['GET'], client.state[:requests]
        client.write "HEAD /admin/ HTTP/1.1\r\n\r\n"
        assert_equal ['GET', 'HEAD'], client.state[:requests]
        client.write "GET /admin/ HTTP/1.1\r\n\r\n"
        assert_equal ['GET', 'HEAD', 'GET'], client.state[:requests]
        
        head_reply = <<-HERE
HTTP/1.1 200 OK\r
Content-Encoding: gzip\r
Content-Length: 158\r
Keep-Alive: timeout=15, max=100\r
Connection: Keep-Alive\r
Content-Type: text/html\r
\r
        HERE

        get_reply = head_reply + 'X'*158

        server.write get_reply
        server.write head_reply
        server.write get_reply

        assert_equal get_reply, client.read
        assert_equal ['HEAD', 'GET'], client.state[:requests]

        assert_equal head_reply, client.read
        assert_equal ['GET'], client.state[:requests]

        assert_equal get_reply, client.read
        assert_equal [], client.state[:requests]
    end

    
end

end
end
end
end
