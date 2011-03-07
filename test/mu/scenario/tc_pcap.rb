# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/scenario/pcap'

module Mu
class Scenario
module Pcap

class Test < Mu::TestCase

    Packet = ::Struct.new(:payload, :skip)
    class Packet
        alias :skip? :skip
    end

    this_dir = File.dirname(File.expand_path(__FILE__))
    PCAP_PATH = "#{this_dir}/sip_signalled_call_1.pcap"
    File.exist?(PCAP_PATH) or raise "Test pcap not found #{PCAP_PATH}"


    def test_validate_pcap_size
        # Backup constants that this test alters.
        max_size_save = Pcap::MAX_PCAP_SIZE
        max_raw_size_save = Pcap::MAX_RAW_PCAP_SIZE
        protos_save = Pcap::EXCLUDE_FROM_SIZE_CHECK
        timeout_save = TSHARK_READ_TIMEOUT

        # Smaller than max size.
        size = Pcap.validate_pcap_size(PCAP_PATH)
        assert_equal 4054, size

        # Equal to max size.
        begin
            Pcap.const_set! :MAX_PCAP_SIZE, 4054
            size = Pcap.validate_pcap_size(PCAP_PATH)
            assert_equal 4054, size
        ensure
            Pcap.const_set! :MAX_PCAP_SIZE, max_size_save
        end

        # Bigger than max size.
        begin
            Pcap.const_set! :MAX_PCAP_SIZE, 4053
            e = assert_raise PcapTooLarge do
                Pcap.validate_pcap_size(PCAP_PATH)
            end
            assert e.message =~ /\b4054\b/, "Exception message should report actual size"
        ensure
            Pcap.const_set! :MAX_PCAP_SIZE, max_size_save
        end

        # Remove rtp from list of filtered protocols. We should report a bigger pcap now.
        begin
            Pcap.const_set! :EXCLUDE_FROM_SIZE_CHECK, []
            size = Pcap.validate_pcap_size(PCAP_PATH)
            assert_equal 4663, size
        ensure
            Pcap.const_set! :EXCLUDE_FROM_SIZE_CHECK, protos_save
        end

        # Add rtcp to list of filtered protocols. We should report a smaller pcap now.
        begin
            Pcap.const_set! :EXCLUDE_FROM_SIZE_CHECK, ['rtp', 'rtcp']
            size = Pcap.validate_pcap_size(PCAP_PATH)
            assert_equal 3548, size
        ensure
            Pcap.const_set! :EXCLUDE_FROM_SIZE_CHECK, protos_save
        end
        
        # Use actual file size in the event of a tshark timeout.
        begin
            Pcap.const_set! :TSHARK_READ_TIMEOUT, 0
            size = Pcap.validate_pcap_size(PCAP_PATH)
            assert_equal File.size(PCAP_PATH), size, "should have reported actual file size on timeout"
        ensure
            Pcap.const_set! :TSHARK_READ_TIMEOUT, timeout_save
        end

        # Use actual file size in the event of a tshark timeout.
        begin
            Pcap.const_set! :MAX_RAW_PCAP_SIZE, 1
            e = assert_raise PcapTooLarge do
                Pcap.validate_pcap_size(PCAP_PATH)
            end
            assert e.message =~ /\b4054\b/, "Exception message should report actual size"
        ensure
            Pcap.const_set! :MAX_RAW_PCAP_SIZE, max_raw_size_save
        end
    ensure
        Pcap.const_set! :TSHARK_READ_TIMEOUT, timeout_save
        Pcap.const_set! :MAX_PCAP_SIZE, max_size_save
        Pcap.const_set! :MAX_RAW_PCAP_SIZE, max_raw_size_save
        Pcap.const_set! :EXCLUDE_FROM_SIZE_CHECK, protos_save
    end

    def test_export_to_archive
        pcap_dir = File.expand_path(File.dirname(__FILE__) + "/test_data")
        Dir.glob("#{pcap_dir}/*.pcap") do |pcap|
            Dir.mktmpdir do |tmp|
                Dir.chdir(tmp) do 
                    io = Pcap.export_to_par pcap
                    open("export.par", 'wb') do |f|
                        while chunk = io.read(4096)
                            f.write chunk
                        end
                    end
                    # Archive file can be extracted.
                    unzipped = system('unzip export.par > out 2>&1')
                    assert unzipped, "failed to extract par file:\n" + File.read('out')

                    # Normalized pcap is well formed.
                    well_formed_pcap = system('tshark -r normalized.pcap > out 2>&1')
                    assert well_formed_pcap, "Tshark did not like this pcap. Is it malformed? \n" + File.read('out')

                end
            end
        end
    end


    RE_MU_RUBY_VER = /1\.8\.6/
    def get_pcap2scenario_ruby
        ENV['PATH'].split(":").each do |dir|
            dir = File.expand_path dir
            ruby = dir + '/ruby'
            if File.file? ruby and File.executable? ruby
                ver = `#{ruby} -v`
                if ver =~ RE_MU_RUBY_VER
                    return ruby
                end
            end
        end

        nil 
    end

    def test_archive_to_scenario
        mu_root = ENV['MU_ROOT']
        if not mu_root
            warn "Skipping pcap2scenario tests because MU_ROOT is not available"
            return
        end

        path_save = ENV['PATH']
        ruby = get_pcap2scenario_ruby
        assert ruby, "Could not find ruby executable that matches #{RE_MU_RUBY_VER}"

        pcap_dir = File.expand_path(File.dirname(__FILE__) + "/test_data")
        msl_dir = File.expand_path("#{mu_root}/test/mu/scenario/from_pcap")
        Dir.glob("#{pcap_dir}/*.pcap") do |pcap|
            expected_msl = File.basename(pcap, '.pcap') + '.msl'
            expected_msl = File.join(msl_dir, expected_msl)
            begin
                Dir.mktmpdir do |tmp|
                    Dir.chdir(tmp) do 
                        # Get par file
                        io = Pcap.export_to_par pcap, :isolate_l7 => true
                        open("export.par", 'wb') do |f|
                            while chunk = io.read(4096)
                                f.write chunk
                            end
                        end

                        # Create scenario from par file.
                        created_scenario = system("#{ruby} #{mu_root}/tools/scenarios/pcap2scenario.rb -wmi export.par > scenario.msl 2> err")
                        assert created_scenario, "Pcap2scenario failed with:\n" + File.read('err')

                        # And make sure result is the same as what you get when starting from pcap.
                        assert_files_same expected_msl, "scenario.msl" 

                    end
                end
            rescue Exception => e
                e.backtrace << "First pcap to failed was #{pcap}. Skipping subsequent pcaps."
                raise e
            end
        end
    end

        

end


end
end
end
