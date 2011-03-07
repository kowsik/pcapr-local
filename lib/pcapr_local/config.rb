# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

module PcaprLocal
module Config

    HOME = ENV["HOME"] || File.expand_path('./')

    DEFAULT_CONFIG = {
        # Shared config.
        "install_dir" => "#{HOME}/pcapr.Local/",
        "pcap_dir"    => "#{HOME}/pcapr.Local/pcaps",
        "index_dir"   => "#{HOME}/pcapr.Local/indexes",

        # UI (Sinatra)
        "app" => {
            "host" => '127.0.0.1',
            "port" => 8080,
        },

        # Pcap scanning
        "scanner" => {
            "interval"    => 60, # scan every n seconds.
            "queue_delay" => 60, # skip file if was modified in last n seconds.
        },

        # Couch
        "couch" => {
            "uri" => 'http://127.0.0.1:5984/',
            "database" => "pcapr_local"
        },

        # Xtractr
        "xtractr" => {
            "path"         => 'xtractr',
            "idle_timeout" => 60  # kill xtractr browser after n seconds of idle time 
        }
    }

    # Return configuration as a Hash. Optionally takes an external
    # configuration file.
    def self.user_config_path
        raise "HOME environment variable is not set" unless ENV['HOME']
        config_dir  = File.join(ENV['HOME'], '.pcapr_local')
        File.join(config_dir, 'config')
    end

    def self.config config_path=nil
        config_path ||= user_config_path

        if not File.exist? config_path
            self.create_config_file config_path
        end

        config = DEFAULT_CONFIG.dup
        begin
            user_config = JSON.parse(File.read(config_path))
        rescue JSON::ParserError => e
            raise "Config file is not well formed JSON, please correct or delete #{config_path}"
        end
        config = config_merge(config, user_config)

        # Derived config (not persisted)
        config['pidfile'] = File.join(config.fetch('install_dir'), '.server.pid')
        config['log_dir'] = File.join(config.fetch('install_dir'), 'log')

        return config
    end

    private

    def self.create_config_file config_path
        config = get_user_config
        FileUtils.mkdir_p File.dirname(config_path)
        File.open config_path, 'w' do |f| 
            f.puts JSON.pretty_generate(config)
        end
        puts "\nThank you. Configuration is saved at #{config_path}."
        sleep 2
    end

    # Recursively applies updates in update config to start config.
    # Does not apply updates unless they are already present in the 
    # starting config
    def self.config_merge start, update
        start = start.dup
        start.to_a.each do |key, val|
            next unless update.include? key
            update_val = update[key]
            if val.is_a? Hash
                if update_val.is_a? Hash
                    # Both values are hashes, recurse.
                    start[key] = config_merge(val, update_val)
                else
                    # Update is not expected type, ignore it.
                end
            else
                start[key] = update_val
            end
        end
        return start
    end

    Opt = Struct.new :key, :default, :validate, :question

    # Interactively gathers configuration from the user and returns config hash.
    def self.get_user_config
        config = JSON.parse(DEFAULT_CONFIG.to_json)
        user_opts = []

        # install dir
        pcap_dir = Opt.new "install_dir"
        pcap_dir.question = "Where should pcapr.Local store user files?"
        pcap_dir.default = "#{HOME}/pcapr.Local"
        pcap_dir.validate = :dir
        user_opts << pcap_dir

        # pcap dir
        pcap_dir = Opt.new "pcap_dir"
        pcap_dir.question = "Which directory would you like to scan for indexable pcaps?"
        pcap_dir.default = Proc.new { File.join(config["install_dir"], 'pcaps') }
        pcap_dir.validate = :dir
        user_opts << pcap_dir

        # index dir
        index_dir = Opt.new "index_dir"
        index_dir.question = "Where would you like to store index files?"
        index_dir.default = Proc.new { File.join(config["install_dir"], 'indexes') }
        index_dir.validate = :dir
        user_opts << index_dir

        # host
        app_host = Opt.new "app.host"
        app_host.question = "What IP address should pcapr.Local run on? Use 0.0.0.0 to listen on all interfaces."
        app_host.default = "127.0.0.1"
        app_host.validate = :app_host
        user_opts << app_host

        # port
        app_port = Opt.new "app.port"
        app_port.question = "What port should pcapr.Local listen on?"
        app_port.default = "8080"
        app_port.validate = :app_port
        user_opts << app_port

        # CouchDB database name
        database = Opt.new "couch.database"
        database.question = "Pick a name for your CouchDB database (database will be created automatically)."
        user = ENV['LOGNAME'] || Process.uid
        database.default = "pcapr_local_#{user}"
        database.validate = :db_name
        user_opts << database

        # CouchDB server
        couch_uri = Opt.new "couch.uri"
        couch_uri.question = "pcapr.Local requires CouchDB to run. Where is your CouchDB server?"
        couch_uri.default = "http://127.0.0.1:5984"
        couch_uri.validate = :couch_uri
        user_opts << couch_uri

        user_opts.each do |opt|
            ask_user opt, config
        end

        return config
    end

    def self.ask_user opt, config
        stty_save = `stty -g`.chomp 
        begin
            # Ask question.
            puts "", opt.question

            # Show default value in prompt and get answer.
            default = opt.default
            if opt.default.is_a? Proc
                default = opt.default.call 
            else
                default = opt.default
            end
            choice = Readline.readline("[#{default}] ").strip
            if choice.empty?
                choice = default 
            end

            # Validate and possibly change answer.
            if opt.validate
                choice = Validate.send(opt.validate, choice, config)
            end
        rescue Validate::Error => e
            puts "\nError: #{e.message}"
            retry
        rescue Interrupt
            system("stty", stty_save)
            puts "\naborting"
            exit 1
        end

        opt_set config, opt.key, choice
    end

    # Navigates nested hashes to set options in the form "foo.bar.baz"
    def self.opt_set hash, dotted_name, value
        keys = dotted_name.split('.')
        last_key = keys.pop
        keys.each {|k| hash = hash[k] }
        hash[last_key] = value
    end

    module Validate
        class Error < StandardError ; end

        def self.app_host host, config
            begin 
                server = TCPServer.new host, 0
                server.close
            rescue => e
                raise Error, "Got error '#{e.message}' when trying to create server for this host. Please pick a different host."
            end
            return host
        end

        def self.dir dir, config
            begin
                dir = File.expand_path dir
                FileUtils.mkdir_p dir
            rescue
                raise Error, "Directory (#{dir}) could not be created. Please choose a different directory."
            end
            return dir
        end

        def self.app_port port, config
            begin
                port = Integer(port)
            rescue
                raise Error, "'#{port}' is not a valid port."
            end
            begin 
                server = TCPServer.new config["app_host"], port
                server.close
            rescue => e
                raise Error, "Got error '#{e.message}' when trying to listen on #{config['app_host']}:#{port}."
            end
            return port
        end

        def self.db_name name, config
            unless name =~ /\A[a-zA-Z0-9_]+\Z/
                raise Error, "Database name can include only letters numbers and underscores."
            end
            return name
        end

        def self.couch_uri uri, config
            # Check couch install is reachable.
            begin
                server = CouchRest::Server.new uri
                server.info
            rescue => e
                err = "Could not connect to couchdb at #{uri}. Got error '#{e.message}'\n"
                if system('which apt-get')
                    install = "sudo apt-get install couchdb"
                    err << "If CouchDB is not installed you may be able to install it with:\n"
                    err << "  'sudo apt-get install couchdb'"
                else
                    err << "Is CouchDB installed?"
                end
                raise Error, err
            end

            # Check that credentials are sufficient by actually creating the database.
            db_name = config['couch']['database']
            begin
                db = DB.get_db "uri" => uri, "database" => db_name, "host" => 'foo', "port" => 3
            rescue RestClient::Exception => e
                err = "Got '#{e.message}' while creating database.\n"
                err << "If you have authentication enabled in CouchDB, please include username and\n"
                err << "password in the URI like:\n"
                err << "  http://user:password@127.0.0.1:5984\n"
                raise Error, err
            end
            return uri 
        end
    end
end
end



