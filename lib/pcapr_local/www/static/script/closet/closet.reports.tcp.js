var closet = closet || {};
closet.reports = closet.reports || [];
closet.reports.push({
    name: 'tcp',
    title: 'TCP',
    apply: function(pcap, fields) {
        return fields.hasOwnProperty('tcp.stream');
    },
    items: [{
        name: 'dport',
        title: 'Destination Ports',
        options: function(pcap, opts, cb) {
            var q = 'flow.proto:6';
            var r = closet.mr.count('flow.service');
            closet.api.flows.report(pcap._id, q, r, function(data) {
                var services = $.map(data.rows, function(row) { return row.key; });
                opts.choice('filter', '', { 'values': [''].concat(services) });
                opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
                opts.choice('order', 'count', { values: ['count', 'port'] });
                opts.boolean('descending', true);
                opts.boolean('normalize', true);
                cb();
            });
        },
        create: function(ctx, $root, pcap, opts) {
            if (opts.order) {
                opts = $.extend({}, opts, {
                    order: { count: 'value', port: 'key' }[opts.order]
                });
            }
            
            var q = 'flow.proto:6';
            q = q + (opts.filter ? ' flow.service:' + opts.filter : '');
            var r = closet.mr.count('flow.dport');
            closet.api.flows.report(pcap._id, q, r, function(data) {
                closet.render.table($root, data, opts);
            });
        }
    }, {
        name: 'bandwidth',
        title: 'Bandwidth Utilization',
        options: function(pcap, opts, cb) {
            var q = 'flow.proto:6';
            closet.api.flows.services(pcap._id, q, 0.0, pcap.index.about.duration, function(data) {
                var services = $.map(data.rows, function(row) { return row.key; });
                opts.choice('filter', '', { 'values': [''].concat(services) });
                opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
                opts.choice('order', 'bytes', { values: ['bytes', 'host'] });
                opts.boolean('descending', true);
                opts.boolean('normalize', false);
                cb();
            });            
        },
        create: function(ctx, $root, pcap, opts) {
            opts = $.extend({}, opts, { value: 'bytes' });
            if (opts.order) {
                opts.order = { bytes: 'value', host: 'key' }[opts.order]
            }
            
            var q = 'flow.proto:6';
            q = q + (opts.filter ? ' flow.service:' + opts.filter : '');
            var r = closet.mr.sum('flow.src', 'flow.bytes');
            closet.api.flows.report(pcap._id, q, r, function(data) {
                closet.render.table($root, data, opts);
            });
        }
    }
    // TODO:
    // - connection rate
    // - scans
    ]
});