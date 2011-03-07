var closet = closet || {};
closet.reports = closet.reports || [];
closet.reports.push({
    name: 'visualize',
    title: 'Visualize',
    apply: function(pcap, fields) {
        return pcap.index.about.flows > 0;
    },
    items:[{
        name: 'flows',
        title: 'Flows',
        options: function(pcap, opts, cb) {
            closet.api.flows.clients(pcap._id, '*', 0.0, pcap.index.about.duration, function(data) {
                var clients = $.map(data.rows, function(row) { return row.key; });
                opts.choice('client', '', { values: [''].concat(clients) });
                closet.api.flows.servers(pcap._id, '*', 0.0, pcap.index.about.duration, function(data) {
                    var servers = $.map(data.rows, function(row) { return row.key; });
                    opts.choice('server', '', { values: [''].concat(servers) });
                    closet.api.flows.services(pcap._id, '*', 0.0, pcap.index.about.duration, function(data) {
                        var services = $.map(data.rows, function(row) { return row.key; });
                        opts.choice('service', '', { values: [''].concat(services) });
                        opts.choice('group', 'service', { values: [ 'service', 'src', 'dst', 'dport' ] });
                        opts.choice('speed', 'normal', { values: [ 'normal', 'slow' ] });
                        cb();
                    });
                });
            });
        },
        create: (function() {
            var globalReportId = 0;
            
            return function(ctx, $root, pcap, opts) {
                var reportId = ++globalReportId;
                var buckets = {};
                var flows = {};
                var packets = [];
                var npackets = 1;
                var timeout = { normal:50, slow:100 }[opts.speed];
                var paused = false;
                var fetching = false;
                var timerId;
                $root.html(
                    '<a class="create" href="javascript:void(0)">create</a>' +
                    '<a class="pause" href="javascript:void(0)" style="display:none">pause</a>' +
                    '<p/>' +
                    '<div class="status" style="padding-bottom:20px"></div>' +
                    '<table class="replay">' +
                    '<tbody>' +
                    '</tbody>' +
                    '</table>' +
                    '<div class="info" style="margin-top:20px"></div>'
                );
            
                var $buckets = $root.find('table.replay tbody');
                var $status = $root.find('div.status');
                var $create = $root.find('a.create');
                var $pause = $root.find('a.pause');
                var $info = $root.find('div.info');
                
                $pause.click(function() {
                    paused = !paused;
                    if (paused) {
                        $pause.text('resume');
                    } else {
                        $pause.text('pause');
                        $info.empty();
                        timerId = timerId || setTimeout(function() { _next(); }, timeout);
                    }
                });
            
                // Create the key used to bucketize the flows
                var _key = function(flow) {
                    if (opts.group === 'dport') {
                        return (flow.proto === 6 ? 'tcp/' : 'udp/') + flow.dport;
                    }
                    return flow[opts.group];
                };
                
                // If we are filtering on a service, map the service to the set
                // of ports so that we can filter the packets that belong to 
                // that flow
                if (opts.service) {
                    var q = 'flow.service:' + closet.util.escapeQuery(opts.service.replace(/-\/.*/, ''));
                    var r = closet.mr.count('flow.dport');
                    closet.api.flows.report(pcap._id, q, r, function(data) {
                        opts.ports = $.map(data.rows, function(row) { return row.key; });
                    });
                }
                
                // Generate the query depending on the opts setting
                var _query = function(id) {
                    var q = 'pkt.flow:>=1 pkt.id:>=' + (id+1);
                    if (opts.client) {
                        var client = closet.util.escapeQuery(opts.client);
                        q += ' ((pkt.dir:0 pkt.src:' + client + ') || (pkt.dir:1 pkt.dst:' + client + '))';
                    }
                    if (opts.server) {
                        var server = closet.util.escapeQuery(opts.server);
                        q += ' ((pkt.dir:0 pkt.dst:' + server + ') || (pkt.dir:1 pkt.src:' + server + '))';
                    }
                    if (opts.ports) {
                        var ports = opts.ports.join('||');
                        q += ' ((pkt.dir:0 udp.dstport|tcp.dstport:(' + ports + ')) || (pkt.dir:1 udp.srcport|tcp.srcport:(' + ports + ')))';
                    }
                    if (opts.group === 'dport') {
                        q += ' (ip.proto:(6||17))';
                    }
                    
                    return q;
                }
                
                // Add a flow to the list. If it's the first flow for a bucket,
                // create the bucket as well.
                var _add = function(flow) {
                    var key = _key(flow);
                    if (!buckets.hasOwnProperty(key)) {
                        var $tr = $(
                            '<tr>' +
                            '<td style="white-space:nowrap">' + closet.util.escapeHTML(key) + '</td>' +
                            '<td class="flows"></td>' +
                            '</tr>'
                        );
                    
                        $buckets.append($tr);
                        buckets[key] = {};
                        buckets[key].$td = $tr.find('td.flows');
                        buckets[key].nflows = 0;
                    }
                
                    var $span = $(
                        '<div class="flow" style="cursor:pointer;float:left;position:relative;background-color:#ffdddd;border:1px solid red;margin-right:5px;margin-left:5px;margin-right:10px;height:1.2em;width:30px">' +
                            '<div class="fill" style="position:absolute;background-color:#e66c25;height:100%;width:1%"></div>' +
                        '</div>'
                    );
                    
                    $span.click(function() {
                        $info.html(
                            'Flow&nbsp;<strong>' + flow.id + '</strong>.&nbsp;' +
                            '<strong>' + flow.src + '</strong>' +
                            '&nbsp;&raquo;&nbsp;' + 
                            '<strong>' + flow.dst + '</strong>' + '&nbsp::&nbsp;' +
                            '<strong>' + closet.util.escapeHTML(flow.service) + '</strong>&nbsp;' +
                            closet.util.escapeHTML(flow.title.slice(0, 80)) +
                            '<p/>' +
                            '<img class="icon" src="/static/image/16x16/Download.png"/>' +
                            'Download <a href="/pcaps/1/pcap/' + pcap._id + '/api/packets/slice?q=pkt.flow:' + flow.id + '">pcap</a> for this flow.'
                        );                        
                    });
                    
                    buckets[key].$td.append($span);
                    buckets[key].nflows++;
                    flow.$span = $span;
                    flow.$fill = $span.find('div.fill');
                    flow.npackets = 1;
                    flows[flow.id] = flow;                    
                };
                
                // Remove a flow from the flow list and if it's the last
                // flow in the bucket, remove the bucketized row as well
                var _remove = function(flow) {
                    var key = _key(flow);
                    setTimeout(function() {
                        delete flows[flow.id];
                        flow.$fill.css('background-color', '#dd1122');
                        flow.$span.fadeOut(1000, function() {
                            $(this).remove();
                            if (--buckets[key].nflows === 0) {
                                var s_entry = buckets[key];
                                delete buckets[key];
                                s_entry.$td.parent('tr').remove();                                        
                            }
                        });
                    }, 100);
                };
            
                var location = ctx.app.getLocation();
                var _next = function() {
                    timerId = undefined;
                    
                    // Abort if the user navigates to a different URL
                    if (ctx.app.getLocation() !== location) { 
                        return; 
                    }
                    
                    // Abort if the user changes 'opts' to create a new viz
                    if (reportId !== globalReportId) { 
                        return; 
                    }
                    
                    // Don't process this packet, if the visualization is paused
                    if (paused) {
                        return;
                    }
                    
                    // When we hit the low water-mark, prefetch (async) the 
                    // next set of packets
                    if (packets.length === 30 && !fetching) {
                        var last = packets[packets.length-1];
                        fetching = true;
                        closet.api.packets.list(pcap._id, { q: _query(last.id), limit: 40, terms: false }, function(data) {
                            fetching = false;
                            packets = packets.concat(data.rows);
                            timerId = timerId || setTimeout(function() { _next(); }, timeout);
                        });
                    }
                
                    // Process the next packet. If there are no more packets
                    // and we are not in the middle of fetching more chunks,
                    // then we are done.
                    var pkt = packets.shift();
                    if (pkt === undefined) {
                        if (!fetching) {
                            $status.empty();
                            $pause.hide();
                            $info.empty();
                            $create.show();
                        }
                        return; 
                    }
                    
                    // Update the status with the current packet
                    $status.html(
                        'Packet &nbsp;<strong>' + pkt.src + '</strong>' +
                        '&nbsp;&raquo;&nbsp;' + 
                        '<strong>' + pkt.dst + '</strong>' + '&nbsp::&nbsp;' +
                        '<strong>' + closet.util.escapeHTML(pkt.service) + '</strong>&nbsp;' +
                        closet.util.escapeHTML(pkt.title.slice(0, 80))
                    );
                
                    // Add/remove flows for this packet
                    if (!flows.hasOwnProperty(pkt.flow)) {
                        closet.api.flows.list(pcap._id, { q: 'flow.id:' + pkt.flow, limit: 1, terms: false }, function(data) {
                            var flow = data.rows[0];
                            _add(flow);
                            if (flow.first === flow.last) {
                                _remove(flow);
                            }                        
                            timerId = timerId || setTimeout(function() { _next(); }, timeout);
                        });
                    } else {
                        var flow = flows[pkt.flow];
                        var key = _key(flow);
                        flow.$fill.css('width', Math.floor((++flow.npackets)*100/flow.packets) + '%');
                        if (flow.last === pkt.id) {
                            _remove(flow);
                        }                    
                        timerId = timerId || setTimeout(function() { _next(); }, timeout);
                    }
                };
            
                $create.click(function() {
                    $(this).hide();
                    $pause.show();
                    $status.html('<span class="throbber">hang on</span>');
                    closet.api.packets.list(pcap._id, { q: _query(0), limit: 100, terms: false }, function(data) {
                        packets = data.rows;
                        _next();
                    });
                });
            };
        }())   
    }]
});
