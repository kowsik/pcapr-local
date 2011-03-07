# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'pcapr_local'
require 'test/pcapr_local/testcase'

module PcaprLocal
class Xtractr

class Test < ::PcaprLocal::Test::TestCase


    PCAP = File.expand_path File.join(File.dirname(__FILE__), "arp.pcap")
    HTTP_PCAP = File.expand_path File.join(File.dirname(__FILE__), "http_chunked.pcap")

    def test_basics
        do_setup

        config = {
           "index_dir" => @index_dir, 
           "reaper_interval" => 60,
           "idle_timeout" => 60,
        }
        xtractr = Xtractr.new config

        config = {
           "db" => @db, 
           "xtractr" => xtractr, 
           "index_dir" => @index_dir, 
           "pcap_dir" => @pcap_dir,
           "queue_delay" => 0,
           "interval" => 0,
        }
        scanner = Scanner.new config

        # Add  pcaps and index them.
        count = 2
        count.times do |n|
            FileUtils.cp PCAP, "#{@pcap_dir}/#{n}.pcap"
        end
        scanner.scan

        # Get an xtractr instance
        x0 = xtractr.xtractr_for('0.pcap')
        assert_kind_of Xtractr::Instance, x0

        # Second request should yield cached instance
        x0_ = xtractr.xtractr_for('0.pcap')
        assert_same x0, x0_

        # A xtractr instance  for a second pcap
        x1 = xtractr.xtractr_for('1.pcap')
        assert_not_same x0,x1
        x1.start
        index_dir1 = scanner.index_path '1.pcap'
        packets_db = File.join(index_dir1, 'packets.db')
        pids = `fuser #{packets_db}`.split
        assert pids.include?(x1.pid.to_s),  "Expected to find xtractr process to have opened packets.db file open"

        # Xtractr instances have not been idle long enough to be reaped.
        xtractr.reap
        assert_nothing_raised do 
            Process.kill 0, x1.pid 
        end

        # Make instance appear idle, it should be reaped now.
        x1_pid = x1.pid
        x1.instance_variable_set :@last_use, 0.0
        xtractr.reap
        assert_nil x1.pid
        assert_raises Errno::ESRCH do
            Process.kill 0, x1_pid 
        end

        # Get another xtractr for same pcap and make sure it is function with a get request.
        x1 = xtractr.xtractr_for('1.pcap')
        status, headers, body = x1.get('/api/fields')
        assert_equal 200, status
        assert_equal({"connection"=>"close", "content-type"=>"text/plain", "server"=>"xtractr"}.to_a.sort, headers.to_a.sort)
        assert_json "[\"pkt.src\",\"pkt.dst\",\"pkt.id\",\"pkt.pcap\",\"pkt.time\",\"pkt.offset\",\"pkt.length\",\"pkt.service\",\"pkt.title\",\"arp.dst.hw.mac\",\"arp.hw.size\",\"arp.hw.type\",\"arp.isgratuitous\",\"arp.opcode\",\"arp.proto.size\",\"arp.proto.type\",\"arp.src.hw.mac\",\"eth.addr\",\"eth.dst\",\"eth.ig\",\"eth.lg\",\"eth.src\",\"eth.type\"]", body

        # Make instance appear idle, it should be reaped now.
        x1_pid = x1.pid
        x1.instance_variable_set :@last_use, 0.0
        xtractr.reap
        assert_nil x1.pid
        assert_raises Errno::ESRCH do
            Process.kill 0, x1_pid 
        end
    ensure
        xtractr.shutdown if xtractr
    end

    XTRACTR_VERSION = "4.5.41604"
    def test_index
        do_setup

        config = {
           "index_dir" => @index_dir, 
           "reaper_interval" => 60,
           "idle_timeout" => 60,
        }
        xtractr = Xtractr.new config

        FileUtils.cp HTTP_PCAP, "#{@pcap_dir}/http.pcap"
        index_data = xtractr.index "#{@pcap_dir}/http.pcap", "#{@index_dir}/http.pcap"
        assert File.exist? "#{@index_dir}/http.pcap/packets.db"
        expected_index_data = { 
            :services =>["http"],
            :about => {
                "packets"  => 2,
                "hosts"    => 2,
                "version"  => XTRACTR_VERSION,
                "services" => 1,
                "duration" => 14,
                "flows"    => 1 
            }
        }

        assert_equal expected_index_data[:services], index_data[:services]
        assert_equal expected_index_data[:about].to_a.sort, index_data[:about].to_a.sort
    ensure
        xtractr.shutdown if xtractr
    end

    def test_free_local_port
        seed = srand
        srand seed
        port1 = Xtractr::Instance.free_local_port
        server1 = TCPServer.open '127.0.0.1', port1

        # Reseed so first port chosen will be in use
        srand seed
        port2 = Xtractr::Instance.free_local_port
        assert_not_equal port1, port2
        server2 = TCPServer.open '127.0.0.1', port2

        server1.close
        server2.close
    end

    def test_do_start
        do_setup

        max_start_time = Instance::MAX_START_TIME
        Instance.const_set :MAX_START_TIME, 1

        config = {
           "index_dir" => @index_dir, 
           "reaper_interval" => 60,
           "idle_timeout" => 60,
        }
        xtractr = Xtractr.new config
        FileUtils.cp HTTP_PCAP, "#{@pcap_dir}/http.pcap"
        index_data = xtractr.index "#{@pcap_dir}/http.pcap", "#{@index_dir}/http.pcap"

        xtractr_instance = Xtractr::Instance.new "#{@index_dir}/http.pcap", EXE_PATH
        xtractr_instance.instance_variable_set :@xtractr_path, `which false`.strip
        assert_raises Instance::XtractrStartupException do 
            xtractr_instance.start
        end
    ensure
        if max_start_time
            Instance.const_set :MAX_START_TIME, max_start_time
        end
    end

    def test_get_and_post
        do_setup

        config = {
           "index_dir" => @index_dir, 
           "reaper_interval" => 60,
           "idle_timeout" => 60,
        }
        xtractr = Xtractr.new config

        config = {
           "db" => @db, 
           "xtractr" => xtractr, 
           "index_dir" => @index_dir, 
           "pcap_dir" => @pcap_dir,
           "queue_delay" => 0,
           "interval" => 0,
        }
        scanner = Scanner.new config

        FileUtils.cp HTTP_PCAP, "#{@pcap_dir}/http.pcap"
        scanner.scan

        # GET /api/about
        status, headers, body = xtractr.get('http.pcap', '/api/about')
        assert_equal 200, status
        assert_kind_of Hash, headers
        assert_equal 'text/plain', headers['content-type']

        about = JSON.parse body
        assert_equal 1, about['flows']
        assert_equal 2, about['packets']

        # POST /api/content?type=text/html&name=content.1.0
        post_body = "bytes=edgbhachhccaengbglchhccahdgjgnhagmgjgggjgfhdcahegigfcahahcgpgdgfhdhdcagpggcagdhcgfgbhegjgoghcahagbgdglgfhecagdgbhahehfhcgfhdcagghcgpgncagdgpgohegfgohecahegigbhecahjgphfcagbgmhcgfgbgehjcagigbhggfcocafjgphfcagdgbgocahfhdgfcaedgbhachhccaengbglchhccahegpcagdgpgnhahcgfhdhdcacihdgpgpgocbcjcmcagfgogdgpgegfcagbgogecagfgngcgfgecagbhcgcgjhehcgbhchjcagdgpgohegfgohecagjgohegpcahggbhcgjgphfhdcahahcgphegpgdgpgmcahdhehcgfgbgnhdcagbgogecahegigfgocagphfhehahfhecagogfhhcahagdgbhahdcacigphggfhccaejfahgdecagphccaejfahgdgcjcocafegigfhcgfchhdcagbcahdgjhkgfcagmgjgngjhecagpggcadcdfeleccagggphccahegigfcagdgpgohegfgohecahjgphfcahfhagmgpgbgecocafjgphfcagdgbgocahfhagmgpgbgecagfhihagmgpgjhehdcmcahggjhchfhdcmcahdhagbgncmcagngbgmhhgbhcgfcmcagfhegddlcagbgohjhegigjgoghcahegigbhecahjgphfcahagmgbgocagpgocahfhdgjgoghcahegpcahegfhdhecaeggjhcgfhhgbgmgmhdcmcaeefaejhdcagbgogecafffeenhdcocafhgfcagegpcagogphecahdhegphcgfcahegigfcagdgpgohegfgohecagpgocahegigfcahdgfhchggfhccagbgogecahegigfcaghgfgogfhcgbhegfgecahagdgbhacagjhdcahjgphfhchdcahegpcaglgfgfhacmcagggphcgfhggfhccoakejggcahjgphfcagigbhggfcagggfgfgegcgbgdglcagphccahdhfghghgfhdhegjgpgohdcagpgocagngbglgjgoghcahegigjhdcagcgfhehegfhccmcagegpcagmgfhecahfhdcaglgogphhcoak"
        status, headers, body = xtractr.post('http.pcap', '/api/content?type=text/html&name=content.1.0', post_body)
        assert_equal 200, status
        assert_kind_of Hash, headers
        assert_equal 'text/html', headers['content-type']
        assert_equal "Cap'r Mak'r simplifies the process of creating packet captures from content that you already have. You can use Cap'r Mak'r to compress (soon!), encode and embed arbitrary content into various protocol streams and then output new pcaps (over IPv4 or IPv6). There's a size limit of 25KB for the content you upload. You can upload exploits, virus, spam, malware, etc; anything that you plan on using to test Firewalls, DPIs and UTMs. We do not store the content on the server and the generated pcap is yours to keep, forever.\nIf you have feedback or suggestions on making this better, do let us know.\n", body


    ensure
        xtractr.shutdown if xtractr
    end

end

end
end
