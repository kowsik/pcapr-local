# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'mu/testcase'
require 'mu/scenario/pcap/fields'

module Mu
class Scenario
module Pcap
class Fields

class Test < Mu::TestCase
    TFIELDS_DATA = <<EOF
pale ale\xffkobe burger\xffmayo
milk shake\xffsundae\xffwhipped cream
\xff\xff
EOF


    def test_basics
        fields_save = FIELDS
        field_count_save = FIELD_COUNT
        Fields.const_set! :FIELDS,  [:"meal.drink", :"meal.entre", :"meal.side"]
        Fields.const_set! :FIELD_COUNT, 3

        read, write = ::IO.pipe
        write.print TFIELDS_DATA

        fields1 = Fields.next_from_io read
        assert_equal 3, fields1.length
        assert_equal "pale ale", fields1[:"meal.drink"]

        fields2 = Fields.next_from_io read
        assert_equal 3, fields2.length
        assert_equal "sundae", fields2[:"meal.entre"]
        assert_equal "whipped cream", fields2[:"meal.side"]

        # nil for empty fields
        fields3 = Fields.next_from_io read
        assert_equal 3, fields3.length
        assert_nil fields3[:"meal.drink"]
        assert_nil fields3[:"meal.entre"]
        assert_nil fields3[:"meal.side"]

        # nil on timeout
        begin
            timeout_save = Pcap.const_get :TSHARK_READ_TIMEOUT
            Pcap.const_set! :TSHARK_READ_TIMEOUT, 0.1
            assert_nil Fields.next_from_io(read)
        ensure
            Pcap.const_set! :TSHARK_READ_TIMEOUT, timeout_save
        end

        # nil on EOFError
        write.close
        assert_nil Fields.next_from_io(read)
    ensure
        Fields.const_set! :FIELDS, fields_save if fields_save
        Fields.const_set! :FIELD_COUNT, field_count_save if field_count_save
    end
end

end
end
end
end
