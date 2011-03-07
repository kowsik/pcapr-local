# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'thread'
require 'net/http'
require 'uri'

module PcaprLocal
class Xtractr
class Instance
    attr_reader :last_use, :lock, :pid, :port

    def initialize index_dir, xtractr_path
        @index_dir = index_dir
        @xtractr_path = xtractr_path
        @lock = Mutex.new
        @last_use = Time.new.to_f # for idle timeouts
        @pid = nil
        @port = nil
    end

    # Does GET request and returns response headers and body.
    def get path_and_params
        start if not @pid
        @lock.synchronize do
            @last_use = Time.new.to_f

            # Make request to xtractr
            uri = URI.parse("http://127.0.0.1:#{@port}/#{path_and_params}")
            response = Net::HTTP.get_response(uri)

            # Copy headers from response
            headers = {}
            response.each_header {|name,val| headers[name] = val}

            return response.code.to_i, headers, response.body
        end
    end

    # Does POST request and returns response headers and body.
    def post path_and_params, post_body
        start if not @pid
        @lock.synchronize do
            @last_use = Time.new.to_f

            # Make request to xtractr
            Net::HTTP.start('localhost', @port) do |http|
                http.request_post "/#{path_and_params}", post_body do |response|
                    headers = {}
                    response.each_header {|name,val| headers[name] = val}
                    return response.code.to_i, headers, response.body
                end
            end
        end
    end

    # Starts underlying process.
    def start
        @lock.synchronize do 
            return if @pid
            err = nil
            # There is a remote possibility that the random port we pick will be
            # in use at the moment we try to bind to it. Thus the retries.
            3.times do  |n|
                begin
                    do_start
                    return
                rescue => err
                end
            end
            raise err
        end
    end

    class XtractrStartupException < XtractrError; end

    # Start xtractr
    MAX_START_TIME = 30 
    RE_STARTED = /starting on http:/i
    def do_start 
        port = Instance.free_local_port
        command = [@xtractr_path, 'browse', @index_dir, '--port', port.to_s]
        Logger.debug "running: #{command.inspect}"
        xtractr_out = Tempfile.new "xtractr_out"
        pid = fork do
            # Xtractr forks a child process. Set process group so we
            # can send signal to all processes in a group.
            Process.setpgid $$, $$
            STDOUT.reopen xtractr_out
            STDERR.reopen xtractr_out
            Dir.chdir @index_dir
            exec *command 
        end

        begin
            Timeout.timeout MAX_START_TIME do 
                # Wait for "starting" line.
                while xtractr_out.grep(/starting on http:\/\/127\.0\.0\.1:#{port}/i).empty?
                    xtractr_out.rewind
                    sleep 0.01
                end
                # Sanity check that server is up.
                Net::HTTP.start('127.0.0.1', port) do |http|
                    http.options("/")
                end
            end
        rescue Timeout::Error, SystemCallError
            Logger.error "Xtractr failed to start on port #{port}"
            xtractr_out.rewind
            Logger.error "Xtractr output: #{xtractr_out.read.inspect}"
            kind_kill -pid
            raise XtractrStartupException, "Timeout waiting for xtractr to startup"
        end
        
        @last_use = Time.new.to_f
        @pid = pid
        @port = port
    end

    # Kills underlying xtractr process.
    def stop
        if @pid
            kind_kill -@pid
            @pid = nil
        end
    end

    # Sends SIGTERM and waits for process to exit. If process does
    # not exit within wait period, sends SIGKILL. Use a negative
    # pid to kill all members of a process group.
    def kind_kill pid, wait=1
        begin
            Process.kill 15, pid
            # Wait for process (or all group members) to
            # exit.
            Timeout.timeout wait do
                loop { Process.wait(pid) }
            end
        rescue Errno::ECHILD, Errno::ESRCH
            # Processes is dead or group has no members.
            return 
        rescue Timeout::Error, StandardError
            # Process did not shutdown in time (or there
            # was an unexpected error).
            Process.kill(9, pid) rescue nil
        end
    end
    
    # Pick a random port over 10000 and verify that it can be bound to (on localhost)
    def self.free_local_port
        while true
            port = rand(0xffff-10000) + 10000
            socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
            socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
            addr = Socket.pack_sockaddr_in(port, '127.0.0.1')
            begin
                socket.bind addr
                return port
            rescue Errno::EADDRINUSE
                next # port in use
            ensure
                socket.close
            end
        end
    end

end
end
end


