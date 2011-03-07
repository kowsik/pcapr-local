# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'pcapr_local'
require 'test/pcapr_local/testcase'

module PcaprLocal
class Scanner

class Test < ::PcaprLocal::Test::TestCase

    class FakeXtractr
        def index pcap_path, index_dir
            FileUtils.mkdir_p "#{index_dir}/terms.db"
            FileUtils.touch "#{index_dir}/packets.db"
            FileUtils.touch "#{index_dir}/terms.db/segments"
            FileUtils.touch "#{index_dir}/terms.db/segments_0"
            return { "fake summary" => 'blah, blah, blah' }
        end
    end

    PCAP = File.expand_path File.join(File.dirname(__FILE__), "arp.pcap")

    def test_find_pcaps
        do_setup

        xtractr = FakeXtractr.new 
        config = {
           "db" => @db, 
           "xtractr" => xtractr, 
           "index_dir" => @index_dir, 
           "pcap_dir" => @pcap_dir,
           "queue_delay" => 0,
           "interval" => 0,
        }
        scanner = Scanner.new config

        # No pcaps
        expected = Set.new
        assert_equal Set.new, scanner.find_pcaps

        # One pcap
        FileUtils.cp PCAP, "#{@pcap_dir}/foo.pcap"
        expected << 'foo.pcap'
        assert_equal expected, scanner.find_pcaps

        # Another
        FileUtils.cp PCAP, "#{@pcap_dir}/bar.cap"
        expected << 'bar.cap'
        assert_equal expected, scanner.find_pcaps

        # Ignore files that don't end in ".pcap" or ".cap"
        FileUtils.cp PCAP, "#{@pcap_dir}/mypcap"
        assert_equal expected, scanner.find_pcaps

        # Should Find pcap in sub directory.
        FileUtils.mkdir_p "#{@pcap_dir}/a/b/c/d"
        assert_equal expected, scanner.find_pcaps
        FileUtils.cp PCAP, "#{@pcap_dir}/a/b/c/d/foo.pcap"
        expected << "a/b/c/d/foo.pcap"
        assert_equal expected, scanner.find_pcaps

        # Should not look into dir whose name begins with a "."
        FileUtils.mkdir_p "#{@pcap_dir}/a/b/c/.d"
        assert_equal expected, scanner.find_pcaps
        FileUtils.cp PCAP, "#{@pcap_dir}/a/b/c/.d/foo.pcap"
        assert_equal expected, scanner.find_pcaps

        # Should handle subdir not searchable.
        system "chmod a-r #{@pcap_dir}/a/b"
        expected.delete "a/b/c/d/foo.pcap"
        assert_equal expected, scanner.find_pcaps
        system "chmod a+r #{@pcap_dir}/a/b"
        expected << "a/b/c/d/foo.pcap"

        # Should handle dir not searchable.
        system "chmod  a-rx #{@pcap_dir}"
        assert_equal Set.new, scanner.find_pcaps
        system "chmod  a+rx #{@pcap_dir}"

        # Should handle dir not searchable.
        system "chmod  a-x #{@pcap_dir}"
        assert_equal Set.new, scanner.find_pcaps
        system "chmod  a+x #{@pcap_dir}"

        # Should handle dir not searchable.
        system "chmod  a-r #{@pcap_dir}"
        assert_equal Set.new, scanner.find_pcaps
        system "chmod  a+r #{@pcap_dir}"

        # Should return empty set if directory is missing.
        dir = "/tmp/test#{rand}#{$$}"
        config['pcap_dir'] = dir
        scanner = Scanner.new config
        expected = Set.new
        assert_equal expected, scanner.find_pcaps

        # Should return empty set if directory is not searchable
        assert_equal expected, scanner.find_pcaps
        dir = "/tmp/test#{rand}#{$$}"
        config['pcap_dir'] = dir
        scanner = Scanner.new config
        expected = Set.new
        assert_equal expected, scanner.find_pcaps
    ensure
        system "chmod -R a+rx #{@pcap_dir}"
    end

    def test_remove_index_for
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

        FileUtils.cp PCAP, "#{@pcap_dir}/foo.pcap"

        # Create index
        index_data = xtractr.index "#{@pcap_dir}/foo.pcap", "#{@index_dir}/foo.pcap"
        assert File.directory? "#{@index_dir}/foo.pcap"
        # Remove it
        scanner.remove_index_for "foo.pcap"
        assert_equal false, File.exist?("#{@index_dir}/foo.pcap")

        # Create index with extra file, index should not be removed.
        index_data = xtractr.index "#{@pcap_dir}/foo.pcap", "#{@index_dir}/foo.pcap"
        FileUtils.touch "#{@index_dir}/foo.pcap/extra_file"
        assert File.directory? "#{@index_dir}/foo.pcap"
        scanner.remove_index_for "foo.pcap"
        assert File.directory? "#{@index_dir}/foo.pcap"
        FileUtils.rm_rf "#{@index_dir}/foo.pcap"
    end

    def test_basics
        do_setup

        xtractr = FakeXtractr.new 
        config = {
           "db" => @db, 
           "xtractr" => xtractr, 
           "index_dir" => @index_dir, 
           "pcap_dir" => @pcap_dir,
           "queue_delay" => 0,
           "interval" => 0,
        }
        scanner = Scanner.new config
        expected = ['.', '..']

        # No pcaps, No indexes
        scanner.scan
        assert_equal expected.sort, Dir.entries(@index_dir).sort

        # One pcap added.  Create one index.
        FileUtils.cp PCAP, "#{@pcap_dir}/foo.pcap"
        scanner.scan
        expected << "foo.pcap"
        assert_equal expected.sort, Dir.entries(@index_dir).sort

        # Two additional pcaps. Should have 3 indexes.
        FileUtils.cp PCAP, "#{@pcap_dir}/bar.pcap"
        FileUtils.cp PCAP, "#{@pcap_dir}/baz.pcap"
        expected << "bar.pcap"
        expected << "baz.pcap"
        scanner.scan
        assert_equal expected.sort, Dir.entries(@index_dir).sort

        # Delete an index, It should be recreated.
        FileUtils.rm_r "#{@index_dir}/bar.pcap"
        expected.delete "bar.pcap"
        assert_equal expected.sort, Dir.entries(@index_dir).sort 
        scanner.scan
        expected << "bar.pcap"
        assert_equal expected.sort, Dir.entries(@index_dir).sort

        # Remove pcap, index should be removed.
        File.unlink "#{@pcap_dir}/baz.pcap"
        expected.delete "baz.pcap"
        scanner.scan
        scanner.scan
        assert_equal expected.sort, Dir.entries(@index_dir).sort

        # Scanner should find pcaps in subdirectory
        FileUtils.mkdir_p "#{@pcap_dir}/a/b/c/d/"
        FileUtils.cp PCAP, "#{@pcap_dir}/a/b/c/d/nested.pcap"
        scanner.scan
        expected << "a"
        assert_equal expected.sort, Dir.entries(@index_dir).sort
        assert File.exist? "#{@index_dir}/a/b/c/d/nested.pcap/terms.db"

        # Pcap should not be indexed until its modification time is older 
        # than queue_delay seconds.
        delay_sec = 2
        config['queue_delay'] = delay_sec
        scanner = Scanner.new config
        FileUtils.cp PCAP, "#{@pcap_dir}/new.pcap"
        scanner.scan  
        assert_equal expected.sort, Dir.entries(@index_dir).sort
        sleep delay_sec + 1
        scanner.scan
        expected << "new.pcap"
        assert_equal expected.sort, Dir.entries(@index_dir).sort

        # Check that database has expected pcaps. 
        expected = [
            {"id"=>"0dddee3f87f14f1621e5744d667a95b7", "value"=>nil, "key"=>"a/b/c/d/nested.pcap"}, 
            {"id"=>"6fc1ee4334c5564563c717bf7ccd734b", "value"=>nil, "key"=>"bar.pcap"}, 
            {"id"=>"291eddbc4e2a539e6df74b141ea434f0", "value"=>nil, "key"=>"foo.pcap"}, 
            {"id"=>"2517876b6c06c5fdcd4745a14ca96491", "value"=>nil, "key"=>"new.pcap"} 
        ]
        by_filename = []
        @db.each_in_view 'pcaps/by_filename' do |row|
            by_filename << row
        end
        by_filename.sort_by {|h| h['key']}
        assert_equal expected, by_filename

        # Check that all pcaps are indexed. 
        @db.each_in_view 'pcaps/by_filename' do |row| 
            doc = @db.get row["id"] 
            assert_equal "indexed", doc.fetch("status")
        end
    end
end

end
end
