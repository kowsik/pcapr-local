#!/bin/bash

set -ex

export MU_ROOT=${MU_ROOT:-~/root2clean}

echo $MU_ROOT

for file in test/mu/scenario/from_pcap/sip_signalled_call_1 test/mu/scenario/from_pcap/arp test/mu/scenario/from_pcap/http-v6 test/mu/scenario/from_pcap/http_chunked test/mu/scenario/from_pcap/http_deflate
do
    file=$MU_ROOT/$file
    for ruby in ruby ruby1.9
    do
        echo "trying $file"
        #$ruby pcap2zip.rb -i $file.pcap /tmp/export.par
        pcap2zip.rb -i $file.pcap /tmp/export.par
        (
        cd $MU_ROOT
        $MU_ROOT/tools/scenarios/pcap2scenario.rb -wmi /tmp/export.par > $file.msl2
        diff $file.msl $file.msl2 && echo passed
        diff $file.msl $file.msl2 #|| echo faileddiffmerge $file.msl $file.msl2
        echo
        )
    done
done
