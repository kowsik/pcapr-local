# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

if defined? Encoding
    Encoding.default_external = Encoding::BINARY
end

test_dir = File.expand_path(File.dirname(__FILE__))
lib_dir =  File.expand_path("#{test_dir}/../lib")

$: << lib_dir
$: << test_dir

require 'environment'
require 'pcapr_local'

Dir.glob("./**/tc_*.rb").each do |testfile|
    require testfile
end

class Module
    def const_set! name, value
        if const_defined? name
            remove_const name
        end
        const_set name, value
    end
end
