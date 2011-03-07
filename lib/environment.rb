# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

if defined? Encoding
    Encoding.default_external = Encoding::BINARY
end

module PcaprLocal
    ROOT = File.expand_path(File.dirname(File.dirname(__FILE__)))
    $: << ROOT
end

class Integer
    # Make sure Integer#ord is present
    if RUBY_VERSION < "1.8.7" 
        def ord
            return self
        end
    end
end 

# Make sure barebones Dir.mktmpdir is present
require 'tempfile'
class Dir
    if not self.respond_to? :mktmpdir
        def self.mktmpdir
            t = (Time.now.to_f * 1_000_000).to_i.to_s(36)
            path = "#{tmpdir}/d#{t}-#{$$}-#{rand(0x100000000).to_s(36)}"
            Dir.mkdir path
            path
        end 
    end
end


module Process
    #  Supply daemon for pre ruby 1.9
    #  Adapted from lib/active_support/core_ext/process/daemon.rb
    def self.daemon(nochdir = nil, noclose = nil)
        exit! if fork                     # Parent exits, child continues.
        Process.setsid                    # Become session leader.
        exit! if fork                     # Zap session leader. See [1].

        unless nochdir
            Dir.chdir "/"                 # Release old working directory.
        end

        unless noclose
            STDIN.reopen "/dev/null"       # Free file descriptors and
            STDOUT.reopen "/dev/null", "a" # point them somewhere sensible.
            STDERR.reopen '/dev/null', 'a'
        end

        trap("TERM") { exit }

        return 0

    end unless self.respond_to? :daemon
end

class Regexp
    # Patch Regexp.union to accept an array
    if RUBY_VERSION < "1.8.7" 
        class << self
            alias :union_pre187 :union
            def union *arg
                if arg.size == 1 and arg[0].is_a? Array
                    arg = arg[0]
                end
                union_pre187 *arg
            end
        end
    end
end 

class String
    # Convert from hex.  E.g. "0d0a".from_hex is "\r\n".
    # Raises ArgumentError on invalid input.
    def from_hex
        return "" if self.empty?
        hex = self
        Integer("0x#{hex}")
        if hex.length % 2 == 1
            hex = "0#{hex}"
        end
        [hex].pack 'H*'
    end
end

# Implement simple Readline.readline if interpreter is not
# compiled with readline support.
begin
    require 'readline'
rescue LoadError
    class Readline
        def self.readline prompt
            print prompt
            gets
        end
    end
end




