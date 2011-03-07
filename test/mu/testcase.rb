# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'tempfile'
require 'test/unit'
require 'pp' # Require to make pp available in tests


module Mu
class TestCase < ::Test::Unit::TestCase
    def setup
        self.reset
    end

    def self.reset
        # Reset random number generator and Time.now to known values
        srand 31337
    end

    def reset
        self.class.reset
    end

    def assert_files_same expected_file, actual_file, message=nil
        expected_file = File.expand_path expected_file
        actual_file = File.expand_path actual_file

        # Set TC_CREATE env variable to create missing stdout files
        create_missing_file = ENV['TC_CREATE'].to_s.length > 0
        # Set TC_UPDATE env variable to update stdout files instead of failing (be careful!)
        bulk_update         = ENV['TC_UPDATE'].to_s.length > 0

        if create_missing_file and not File.exists? expected_file
            File.open("/dev/tty", 'w') do |tty| 
                tty.puts "Warning: copying #{actual_file} to #{expected_file}"
            end
            File.open(expected_file, 'w') {|f| f.write File.read(actual_file)}
        end

        assert File.exists?(expected_file), "File #{expected_file.inspect} does not exist"
        assert File.exists?(actual_file), "File #{actual_file.inspect} does not exist"

        message ||= "Files differ: #{expected_file} #{actual_file}"
        assert_block message do 
            $stderr.puts `diff -ub #{expected_file} #{actual_file} 2>&1`
            if $?.exitstatus == 0 
                return true
            end

            # Hook for graphical diff/merge tools
            if diff = ENV['DIFF']
                puts `#{diff} #{expected_file} #{actual_file}`
            else
                $stderr.puts "You may want to rerun test with DIFF env variable set to a graphical diff/merge tool"
            end

            if bulk_update
                File.open("/dev/tty", 'w') do |tty|
                    tty.puts "Warning: updating expected output at #{actual_file} to #{expected_file}" 
                end
                File.open(expected_file, 'w') {|f| f.write File.read(actual_file)}
                next true
            end

            false
        end
    end

    # Suppress output to stderr.  For testing code that may log to stderr.
    def with_no_stderr # block
        begin
            old_stderr = $stderr
            $stderr = StringIO.new
            yield
        ensure
            $stderr = old_stderr
        end
    end

    def default_test
        # Defining this method prevents this class from running and failing
        # due to lack of tests.
    end
end
end
