# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'rubygems'
require 'environment'
require 'pcapr_local/config'
require 'pcapr_local/scanner'
require 'pcapr_local/server'
require 'pcapr_local/xtractr'
require 'logger'

module PcaprLocal
    START_SCRIPT = File.join(ROOT, 'bin/pcapr_start.rb')

    # We share a single Logger across all of pcapr.Local.
    Logger = Logger.new(STDOUT)

    # Recreate logger using configured log location.
    LOGFILE = "server.log"
    def self.start_logging log_dir
        if log_dir and not log_dir.empty?
            if const_defined? :Logger
                remove_const :Logger
            end

            logfile = File.join(log_dir, LOGFILE)
            FileUtils.mkdir_p log_dir
            const_set :Logger, Logger.new(logfile, 5)
        end
    end

    # Start xtractr instance manager.
    def self.start_xtractr config
        xtractr_config = config['xtractr'].merge(
            "index_dir" => config.fetch("index_dir"),
            "pcap_dir"  => config.fetch("pcap_dir")
        )
        Xtractr.new xtractr_config
    end

    # Start file system scanner.
    def self.start_scanner config, db, xtractr
        scanner_config = config.fetch('scanner').merge( 
            "index_dir" => config.fetch("index_dir"),
            "pcap_dir" => config.fetch("pcap_dir"),
            "db" => db,
            "xtractr" => xtractr
        )
        PcaprLocal::Scanner.start scanner_config
    end

    # Start webserver UI/API
    def self.start_app config, db, scanner, xtractr
        app_config = config.fetch "app"
        root = File.expand_path(File.dirname(__FILE__))
        app_file = File.join(root, "pcapr_local/server.rb")
        PcaprLocal::Server.run! \
            :app_file => app_file,
            :dump_errors => true,
            :logging => true,
            :port    => app_config.fetch("port"), 
            :bind    => app_config.fetch("host"),
            :db      => db,
            :scanner => scanner,
            :xtractr => xtractr
    end

    def self.get_db config
        PcaprLocal::DB.get_db config.fetch("couch")
    end

    def self.start config=nil
        config ||= PcaprLocal::Config.config
        
        # Check that server is not already running.
        check_pid_file config['pidfile']

        # Start logging.
        if config["log_dir"]
            start_logging config['log_dir']
        end
        start_msg = "Starting server at #{config['app']['host']}:#{config['app']['port']}"
        Logger.info start_msg
        puts start_msg
        puts "Log is at #{config['log_dir']}/#{LOGFILE}"

        # Deamonize
        unless config['debug_mode']
            puts "Moving server process to the background. Run 'stoppcapr' to stop the server."
            Process.daemon
        end

        # Create pid file that will be deleted when we shutdown.
        create_pid_file config['pidfile']

        # Get database instance
        db = get_db config

        # Xtractr manager
        xtractr = start_xtractr config

        # Start scanner thread
        scanner = start_scanner config, db, xtractr

        # Start application server
        start_app config, db, scanner, xtractr
    end

    def self.check_pid_file file
        if File.exist? file
            # If we get Errno::ESRCH then process does not exist and
            # we can safely cleanup the pid file.
            pid = File.read(file).to_i
            begin 
                Process.kill(0, pid)
            rescue Errno::ESRCH
                stale_pid = true
            rescue 
            end

            unless stale_pid 
                puts "Server is already running (pid=#{pid})"
                exit
            end
        end
    end

    def self.create_pid_file file
        File.open(file, "w") { |f| f.puts Process.pid }

        # Remove pid file during shutdown
        at_exit do 
            Logger.info "Shutting down." rescue nil
            if File.exist? file
                File.unlink file
            end
        end
    end

    # Sends SIGTERM to process in pidfile. Server should trap this
    # and shutdown cleanly.
    def self.stop config=nil
        user_config = Config.user_config_path
        if File.exist?(user_config)
            config = PcaprLocal::Config.config user_config
            pid_file = config["pidfile"]
            if pid_file and File.exist? pid_file
                pid = Integer(File.read(pid_file))
                Process.kill -15, -pid
            end
        end
    end
end

if __FILE__ == $0
    PcaprLocal.start
end

