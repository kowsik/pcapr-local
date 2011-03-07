# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'thread'
require 'net/http'
require 'uri'

module PcaprLocal
class Xtractr
    class XtractrError < StandardError; end

    EXE_PATH = File.join(ROOT, 'lib/exe/xtractr')
    
    def initialize config
        @xtractr_path = EXE_PATH
        @idle_timeout = config.fetch("idle_timeout")
        @index_dir    = config.fetch("index_dir")
        @reaper_interval = config.fetch("reaper_interval", REAPER_INTERVAL)
        # Hash of index dir to xtractr instance.
        @xcache = {}
        # Lock to synchronize creation/destruction of xtractr instances.
        @xcache_lock = Mutex.new

        start_reaper
        at_exit do
            shutdown
        end 
    end

    # Idle xtractr process reaper runs every REAPER_INTERVAL seconds.
    REAPER_INTERVAL = 10 

    # Start reaper thread.
    def start_reaper
        Thread.new do
            loop do
                begin
                    reap
                rescue Exception
                    Logger.error "Exception while cleaning up idle processes: #{e.message}\n" + e.backtrace.join("\n")
                end
                sleep @reaper_interval
            end
        end
    end

    # Kill xtractr instances at exit (idle or not).
    def shutdown
        @xcache.each_value do |xtractr|
            $stderr.puts "stopping xtractr process"
            xtractr.stop rescue nil
        end
    end

    # Kills idle xtractr processes
    def reap
        @xcache_lock.synchronize do 
            @xcache.to_a.each do |dir, xtractr|
                if xtractr.lock.try_lock
                    # xtractr is not in use right now
                    begin
                        if xtractr.last_use + @idle_timeout < Time.new.to_f
                            xtractr.stop
                            @xcache.delete dir
                        end
                    ensure
                        xtractr.lock.unlock
                    end
                end
            end
        end
    end

    # Does path look like an xtractr index directory?
    def self.index_dir?(path)
        File.exist? File.join(path, 'packets.db')
    end

    # Returns timestamp (float) for xtractr index.
    def self.index_time(path)
        db_file = File.join(path, 'packets.db')
        if File.exists? db_file
            File.mtime(db_file).to_f
        elsif File.exists? path
            File.mtime(path).to_f
        else
            0.0
        end
    end

    class XtractrIndexingException < XtractrError; end

    # Last line of normal xtractr indexing output.
    RE_INDEXING_DONE = /optimizing terms\.db\.\.\.done/

    # Indexes pcap it index_dir and returns hash containing xtractr summary data.
    # Raises exception if indexing fails.
    def index pcap_path, index_dir
        FileUtils.mkdir_p index_dir

        command = [@xtractr_path, 'index', index_dir, '--mode', 'forensics', pcap_path]
        Logger.debug "running: #{command.inspect}"
        xtractr_out = Tempfile.new "xtractr_out"
        pid = fork do
            # Xtractr forks a child process. Set process group so we
            # can send signal to all processes in a group.
            STDOUT.reopen xtractr_out
            STDERR.reopen xtractr_out
            exec *command 
        end
        #XXX enforce timeout.
        Process.wait pid 

        xtractr_out.rewind
        output = xtractr_out.read

        unless $?.exitstatus == 0 and Xtractr.index_dir?(index_dir) and output =~ RE_INDEXING_DONE
            Logger.error "Indexing failed with output:\n" + output
            raise XtractrIndexingException, "Indexing failed"
        end

        return get_summary(index_dir)
    ensure
        xtractr_out.close! if xtractr_out
    end

    def get_summary index_dir
        # Start xtractr in browse mode and get summary data
        browser = Instance.new index_dir, @xtractr_path
        about = JSON.parse(browser.get('api/about')[2])
        services = JSON.parse(browser.get('api/services')[2])
        service_names = []
        services["rows"].each do |row|
            service_names << row['name'].downcase
        end
        return { :about => about, :services => service_names }
    ensure
        browser.stop if browser
    end
    
    # Forwards GET request to xtractr instance created for index_dir.
    # A relative path will be expanded relative to the configured index_dir.
    def get index_dir, url
        xtractr = nil
        xtractr = xtractr_for index_dir
        xtractr.get url
    end

    # Forwards POST request to xtractr instance created for index_dir.
    # A relative path will be expanded relative to the configured index_dir.
    def post index_dir, url, body
        xtractr = nil
        xtractr = xtractr_for index_dir
        xtractr.post url, body
    end

    def xtractr_for index_dir
        # Ensure index_dir path is absolute.
        if index_dir.slice(0,1) != '/'
            index_dir = File.expand_path(File.join(@index_dir, index_dir))
        end

        # Get or create xtractr instance.
        @xcache_lock.synchronize do
            xtractr = @xcache[index_dir]
            if not xtractr
                xtractr = Instance.new(index_dir, @xtractr_path)
                @xcache[index_dir] = xtractr
            end
            return xtractr
        end
    end

end
end


require 'pcapr_local/xtractr/instance'
