# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

$: << File.expand_path(File.dirname(__FILE__) + '../../../../lib')
$stderr.puts $:

require 'pcapr_local'
require 'test/unit'
require 'mu/testcase'

module PcaprLocal
module Test

class TestCase < Mu::TestCase
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

    # Sets up database file system and config. 
    # Intentionally not using setup method for ease of debugging.
    def do_setup 
        config = self.config
        host = config['app']['host']
        port = config['app']['port']
        @url_base = "http://#{host}:#{port}"
        puts config.inspect
        @pcap_dir = config.fetch 'pcap_dir'
        @index_dir = config.fetch 'index_dir'

        # Extract test pcaps and indexes
        FileUtils.rm_rf '/tmp/pcapr_local_test'
        FileUtils.mkdir_p @pcap_dir
        FileUtils.mkdir_p @index_dir


        # Recreate test database.
        begin
            couch = config['couch']
            RestClient.delete "#{couch['uri']}/#{couch['database']}"
        rescue RestClient::ResourceNotFound
        end
        db = @db = PcaprLocal.get_db(config)
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
end
end
