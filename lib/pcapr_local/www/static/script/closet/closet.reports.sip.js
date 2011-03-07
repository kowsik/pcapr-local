var closet = closet || {};
closet.reports = closet.reports || [];
closet.reports.push({
    name: 'sip',
    title: 'SIP',
    apply: function(pcap, fields) {
        return fields.hasOwnProperty('sip.method');
    },
    items: [{
        name: 'calls',
        title: 'Calls',
        apply: function(pcap, fields) {
            return fields.hasOwnProperty('sip.call.id');
        },
        create: function(ctx, $root, pcap, opts) {
            var calls = [];
            
            var $status = $root.find('span.throbber');
            
            // 1. Find all the unique call-ids in the pcap
            var q = 'pkt.service:sip* sip.method:invite';
            var r = closet.mr.count('sip.call.id');
            closet.api.packets.report(pcap._id, q, r, function(data) {
                async.forEachSeries(data.rows, 
                    function(row, next) {
                        var call = { id: row.key };
                        calls.push(call);
                        
                        $status.text('processing call-id ' + call.id);
                        
                        // 2. Find the first INVITE that has this callid. This tell us
                        // who started the call.
                        q = 'pkt.service:sip* sip.method:invite sip.call.id:' + closet.util.escapeQuery(call.id);
                        closet.api.packets.list(pcap._id, { q:q, limit:1, include_fields:true }, function(data) {
                            var pkt = data.rows[0];
                            call.src = pkt.src;
                            call.dst = pkt.dst;
                            pkt.fields = closet.util.kvsToObject(pkt.fields);
                            call.from = (pkt.fields['sip.from.user']||['unknown'])[0].replace(/;.*$/, '');
                            call.to = (pkt.fields['sip.to.user']||['unknown'])[0].replace(/;.*$/, '');

                            // 3. Find the unique SIP flows that make up this call
                            q = 'sip.call.id:' + closet.util.escapeQuery(call.id);
                            var r = closet.mr.count('pkt.flow');
                            closet.api.packets.report(pcap._id, q, r, function(data) {
                                var fids = $.map(data.rows, function(row) { return row.key; });
                                
                                // 4. And fetch the flow information
                                var qf = 'flow.id:(' + fids.join('||') + ')';
                                closet.api.flows.list(pcap._id, { q: qf }, function(data) {
                                    call.flows = data.rows;
                                    
                                    // 5. Compute the span for this call-leg
                                    call.span = {};
                                    $.each(call.flows, function(_, flow) {
                                        call.span.min = Math.min(call.span.min || flow.first, flow.first);
                                        call.span.max = Math.max(call.span.max || flow.last, flow.last);
                                    });
                                    
                                    $status.text('extracting RTP streams for call-id ' + call.id);
                                    
                                    // 5. For this call-id, look for sdp packets that contain RTP information
                                    var qrtp = 'sip.call.id:' + closet.util.escapeQuery(call.id) + ' sdp.version:0';
                                    closet.api.packets.list(pcap._id, { q: qrtp, include_fields: true }, function(data) {
                                        var rtps = { ips: [], ports: [], media: [] };
                                        $.each(data.rows, function(_, pkt) {
                                            pkt.fields = closet.util.kvsToObject(pkt.fields);
                                            var ips = pkt.fields['sdp.connection.info.address'];
                                            var ports = pkt.fields['sdp.media.port'];
                                            var media = pkt.fields['sdp.mime.type'];
                                            rtps.ips = rtps.ips.concat(ips || []);
                                            rtps.ports = rtps.ports.concat(ports || []);
                                            rtps.media = rtps.media.concat(media || []);
                                        });

                                        // 6. And then stitch the RTP flows within the span together with the SIP flows
                                        var qfrtp = 'flow.first:>=' + call.span.min + ' flow.last:<=' + call.span.max + ' flow.service:RTP flow.dst:(' + rtps.ips.join('||') + ') flow.dport:(' + rtps.ports.join('||') + ')';
                                        closet.api.flows.list(pcap._id, { q: qfrtp }, function(data) {
                                            call.flows = call.flows.concat(data.rows);
                                            call.rtp = data.rows;
                                            call.media = closet.util.unique(rtps.media);

                                            // Compute the #total packets for this call-leg
                                            var fids = $.map(call.flows, function(flow) { return flow.id; });
                                            call.q = 'pkt.flow:(' + fids.join('||') + ')';
                                            call.packets = 0;
                                            $.each(call.flows, function(_, flow) {
                                                call.packets += flow.packets;
                                            });
                                            next();
                                        });
                                    });
                                });
                            });
                        });
                    },
                    function() {
                        // TODO:
                        // - For each flow that matches the call-id, show the call-flow
                        // - Show statistics about the message types + error codes
                        ctx.render('/templates/sip.calls.template', { pcap: pcap, calls: calls }, function(content) {
                            $root.html(content);
                        });
                    }
                );
            });
        }
    }, {
        name: 'phones',
        title: 'Phones',
        apply: function(pcap, fields) {
            return fields.hasOwnProperty('sip.user.agent');
        },        
        options: function(pcap, opts, cb) {
            opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
            opts.choice('order', 'count', { values: [ 'count', 'phone' ] });
            opts.boolean('descending', true);
            opts.boolean('normalize', true);
            cb();
        },
        create: function(ctx, $root, pcap, opts) {
            opts = $.extend({}, opts, { value: 'count' });
            if (opts.order) {
                opts.order = { count: 'value', phone: 'key' }[opts.order];
            }
            
            var q = 'flow.service:sip*';
            var r = closet.mr.count('sip.user.agent');
            closet.api.flows.report(pcap._id, q, r, function(data) {
                closet.render.table($root, data, opts);
            });
        }
    },{
        name: 'servers',
        title: 'Servers',
        apply: function(pcap, fields) {
            return fields.hasOwnProperty('sip.server');
        },
        options: function(pcap, opts, cb) {
            opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
            opts.choice('order', 'count', { values: [ 'count', 'server' ] });
            opts.boolean('descending', true);
            opts.boolean('normalize', true);
            cb();
        },
        create: function(ctx, $root, pcap, opts) {
            opts = $.extend({}, opts, { value: 'count' });
            if (opts.order) {
                opts.order = { count: 'value', server: 'key' }[opts.order];
            }
            
            var q = 'flow.service:sip*';
            var r = closet.mr.count('sip.server');
            closet.api.flows.report(pcap._id, q, r, function(data) {
                closet.render.table($root, data, opts);
            });
        }
    }]
});