# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

$: << File.expand_path(File.dirname(__FILE__) + '../../../../lib')

require 'pcapr_local'
require 'test/unit'

module CouchTest
    def datafile
        nil
    end

    # Returns user config but with parameters to changed to prevent clobbering user data.
    def config
        config = PcaprLocal::Config.config
        config['couch']['database'] = "#{config['couch']['database']}_test"
        config['install_dir'] = "/tmp/pcapr_local_test"
        config['pcap_dir'] = "/tmp/pcapr_local_test/pcaps"
        config['index_dir'] = "/tmp/pcapr_local_test/indexes"
        config['app']['port'] = config['app']['port'].to_i + 1
        config
    end

    # Starts pcapr_local in separate process
    def setup
        config = self.config
        host = config['app']['host']
        port = config['app']['port']
        @url_base = "http://#{host}:#{port}"

        # Extract test pcaps and indexes
        FileUtils.rm_rf '/tmp/pcapr_local_test'
        test_tar = File.join(File.expand_path(File.dirname(__FILE__)), 'test.tgz')
        if File.exist? test_tar
            puts `tar -C /tmp/ -xzf #{test_tar}`
        end

        # Recreate test database.
        begin
            couch = config['couch']
            RestClient.delete "#{couch['uri']}/#{couch['database']}"
        rescue RestClient::ResourceNotFound
        end
        db = PcaprLocal.get_db config

        # And restore it from datafile.
        if self.datafile
            load_docs self.datafile, db
        end

        # Start server.
        config_file = Tempfile.new "config"
        config_file.print config.to_json
        config_file.flush
        @pid = fork do 
            Process.setpgid $$, $$
            exec "#{PcaprLocal::ROOT}/bin/startpcapr -f #{config_file.path} -d" 
        end

        # And wait for it to be ready.
        wait_for_server host, port
    end

    def wait_for_server host, port, time=10
        stop = Time.new + time
        while Time.new < stop
            if s = TCPSocket.open(host, port) rescue nil
                s.close
                return
            end
            sleep 0.01
        end

        raise "Server at #{host}:#{port} took longer than #{time} seconds to start"
    end

    def teardown
        # stop server
        if @pid
            Process.kill -2, @pid 
            Process.wait @pid
            @pid = nil
        end
    end

    def load_docs doc_file, db
        open doc_file do |js|
            while line = js.gets
                doc = JSON.parse line
                doc.delete '_rev'
                db.save_doc doc, true
            end

            db.bulk_save
        end
    end

    def assert_json s1, s2, msg=nil
        o1 = JSON.parse s1
        o2 = JSON.parse s2

        if o1.is_a? Hash
            o1.delete "_rev"
        end

        if o2.is_a? Hash
            o2.delete "_rev"
        end

        assert_equal o1, o2, msg
    end
end

class CouchTestBasic < Test::Unit::TestCase
    include CouchTest

    def datafile
        File.join(File.dirname(__FILE__), 'data.js')
    end

    def test_basic
        # Main page 
        r = RestClient.get @url_base
        assert_match "pcapr.Local", r

        # Status
        r = RestClient.get "#{@url_base}/pcaps/1/status"
        assert_equal '{"indexed,1292981418000":3}', r

        # Statistics
        r = RestClient.get "#{@url_base}/pcaps/1/statistics"
        assert_json '{"packets":52,"bytes":14479,"services":14,"flows":9,"pcaps":3}', r

        # List
        list = {
            'date'      => %q{{"rows":[{"id":"6808db6ca2264c01780e7fb4fb5c9022","value":null,"key":1292981418000},{"id":"6808db6ca2264c01780e7fb4fb5c9ada","value":null,"key":1292981418000},{"id":"6808db6ca2264c01780e7fb4fb5ca623","value":null,"key":1292981418000}],"offset":0,"total_rows":3}},
            'path'      => %q{{"rows":[{"value":3,"key":null}]}},
            'status'    => %q{{"rows":[{"value":3,"key":null}]}},
            'service'   => %q{{"rows":[{"value":14,"key":null}]}},
            'keyword'   => %q{{"rows":[{"value":7,"key":null}]}},
            'filename'  => %q{{"rows":[{"id":"6808db6ca2264c01780e7fb4fb5ca623","value":null,"key":"A1.pcap"},{"id":"6808db6ca2264c01780e7fb4fb5c9022","value":null,"key":"arp.pcap"},{"id":"6808db6ca2264c01780e7fb4fb5c9ada","value":null,"key":"sip_signalled_call_1.pcap"}],"offset":0,"total_rows":3}},
            'directory' => %q{{"rows":[{"value":3,"key":null}]}}
        }

        r = RestClient.get "#{@url_base}/pcaps/1/list"
        assert_json list['date'], r

        list.keys.each do |key|
            r = RestClient.get "#{@url_base}/pcaps/1/list?by=#{key}"
            assert_json list[key], r, "unexpected result when listing by key '#{key}'"
        end

        # About
        r = RestClient.get "#{@url_base}/pcaps/1/about/6808db6ca2264c01780e7fb4fb5c9ada"
        assert_json %q{{"status":"indexed","updated_at":"2010/12/22 01:30:26 +0000","_id":"6808db6ca2264c01780e7fb4fb5c9ada","_rev":"1-2fcf4b207c34b4928bf08945a084a1e7","type":"pcap","filename":"sip_signalled_call_1.pcap","index":{"about":{"packets":22,"hosts":5,"version":"4.5.41604","services":6,"flows":4,"duration":6.29398},"services":["arp","sip/sdp","sip","rtcp","rtp","icmp"]},"stat":{"inode":6395187,"size":5039,"ctime":"2010/12/21 02:04:04 +0000"},"created_at":"2010/12/22 01:30:18 +0000"}}, r

        # Remove
        r = RestClient.get "#{@url_base}/pcaps/1/remove/6808db6ca2264c01780e7fb4fb5c9ada"
        assert_json %q{{"error":true,"reason":"status is not failed"}}, r

        # Explore on pcapr
        r = RestClient.get "#{@url_base}/pcaps/1/pcap/6808db6ca2264c01780e7fb4fb5c9ada"
        assert_match /pcapr/, r, "Doesn't look like we got redirected to pcapr"

        # Forward to xtractr API
        r = RestClient.get "#{@url_base}/pcaps/1/pcap/6808db6ca2264c01780e7fb4fb5c9ada/api/fields"
        assert_equal %q{["pkt.src","pkt.dst","pkt.flow","pkt.id","pkt.pcap","pkt.first","pkt.dir","pkt.time","pkt.offset","pkt.length","pkt.service","pkt.title","arp.dst.hw.mac","arp.hw.size","arp.hw.type","arp.isgratuitous","arp.opcode","arp.proto.size","arp.proto.type","arp.src.hw.mac","eth.addr","eth.dst","eth.ig","eth.lg","eth.src","eth.type","icmp.code","icmp.type","ip.dsfield","ip.dsfield.ce","ip.dsfield.dscp","ip.dsfield.ect","ip.dst.host","ip.flags","ip.flags.df","ip.flags.mf","ip.flags.rb","ip.frag.offset","ip.hdr.len","ip.host","ip.id","ip.len","ip.proto","ip.src.host","ip.ttl","ip.version","rtcp.length","rtcp.length.check","rtcp.padding","rtcp.pt","rtcp.rc","rtcp.sc","rtcp.sdes.length","rtcp.sdes.text","rtcp.sdes.type","rtcp.sender.octetcount","rtcp.sender.packetcount","rtcp.senderssrc","rtcp.setup.frame","rtcp.setup.method","rtcp.ssrc.cum.nr","rtcp.ssrc.dlsr","rtcp.ssrc.ext.high","rtcp.ssrc.fraction","rtcp.ssrc.high.cycles","rtcp.ssrc.high.seq","rtcp.ssrc.identifier","rtcp.ssrc.jitter","rtcp.ssrc.lsr","rtcp.timestamp.ntp","rtcp.timestamp.ntp.lsw","rtcp.timestamp.ntp.msw","rtcp.timestamp.rtp","rtcp.version","rtp.cc","rtp.ext","rtp.extseq","rtp.marker","rtp.p.type","rtp.padding","rtp.seq","rtp.setup.frame","rtp.setup.method","rtp.ssrc","rtp.timestamp","rtp.version","sdp.connection.info","sdp.connection.info.address","sdp.connection.info.address.type","sdp.fmtp.parameter","sdp.media","sdp.media.attr","sdp.media.attribute.field","sdp.media.attribute.value","sdp.media.format","sdp.media.media","sdp.media.port","sdp.media.proto","sdp.mime.type","sdp.owner","sdp.owner.address","sdp.owner.address.type","sdp.owner.sessionid","sdp.owner.username","sdp.owner.version","sdp.sample.rate","sdp.session.name","sdp.time","sdp.time.start","sdp.time.stop","sdp.version","sip.allow","sip.call.id","sip.contact","sip.content.length","sip.content.type","sip.cseq","sip.cseq.method","sip.cseq.seq","sip.from.addr","sip.from.host","sip.from.user","sip.max.forwards","sip.method","sip.msg.hdr","sip.r.uri","sip.r.uri.host","sip.r.uri.user","sip.release.time","sip.request.line","sip.resend","sip.response.request","sip.response.time","sip.server","sip.status.code","sip.status.line","sip.supported","sip.tag","sip.to","sip.to.addr","sip.to.host","sip.to.user","sip.user.agent","sip.via","udp.dstport","udp.length","udp.port","udp.srcport"]}, r
        
        # Export to zip
        zip = RestClient.get "#{@url_base}/pcaps/1/export_to_par/6808db6ca2264c01780e7fb4fb5c9ada"
        Tempfile.open 'zip' do |io| 
            io.write zip
            io.flush
            unzip = `unzip -l #{io.path} |awk '{print $4}'`
            assert_equal "\nName\n----\nabout\npdml\npsml\nfields\npackets.dump\nnormalized.pcap\n\n\n", unzip
        end

    end
end
