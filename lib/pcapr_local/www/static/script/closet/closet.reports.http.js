var closet = closet || {};
closet.reports = closet.reports || [];
closet.reports.push({
    name: 'http',
    title: 'HTTP',
    apply: function(pcap, fields) {
        return fields.hasOwnProperty('http.request.method');
    },
    items: [{
        name: 'latency',
        title: 'Response Times',
        options: function(pcap, opts, cb) {
            opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
            opts.choice('order', 'spread', { values: ['min', 'max', 'count', 'spread'] });
            opts.boolean('descending', true);
            cb();
        },
        create: function(ctx, $root, pcap, opts) {
            var q = 'flow.service:http*';
            var r = closet.mr.minmax('http.request.uri', 'flow.duration');
            closet.api.flows.report(pcap._id, q, r, function(data) {
                closet.render.minmax($root, data, opts);
            });
        }
    }, {
        name: 'bandwidth',
        title: 'Bandwidth Utilization',
        options: function(pcap, opts, cb) {
            var q = 'flow.service:http*';
            closet.api.flows.servers(pcap._id, q, 0.0, pcap.index.about.duration, function(data) {
                var servers = $.map(data.rows, function(row) { return row.key; });
                opts.choice('server', '', { 'values': [''].concat(servers) });
                opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
                opts.choice('order', 'bytes', { values: [ 'bytes', 'uri' ] });
                opts.boolean('descending', true);
                opts.boolean('normalize', false);
                cb();
            });
        },
        create: function(ctx, $root, pcap, opts) {
            opts = $.extend({}, opts, { value: 'bytes' });
            if (opts.order) {
                opts.order = { uri: 'value', host: 'key' }[opts.order]
            }
            
            var q = 'flow.service:http*';
            q = q + (opts.server ? ' flow.dst:' + opts.server : '');
            var r = closet.mr.sum('http.request.uri', 'flow.bytes');
            closet.api.flows.report(pcap._id, q, r, function(data) {
                closet.render.table($root, data, opts);
            });
        }
    }, {
        name: 'browsers',
        title: 'Web Browsers',
        options: function(pcap, opts, cb) {
            var q = 'flow.service:http*';
            closet.api.flows.servers(pcap._id, q, 0.0, pcap.index.about.duration, function(data) {
                var servers = $.map(data.rows, function(row) { return row.key; });
                opts.choice('server', '', { 'values': [''].concat(servers) });
                opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
                opts.choice('order', 'count', { values: [ 'count', 'browser' ] });
                opts.boolean('descending', true);
                opts.boolean('normalize', true);
                cb();
            });
        },
        create: function(ctx, $root, pcap, opts) {
            opts = $.extend({}, opts, { value: 'count' });
            if (opts.order) {
                opts.order = { count: 'value', browser: 'key' }[opts.order]
            }
            
            var q = 'flow.service:http*';
            q = q + (opts.server ? ' flow.dst:' + opts.server : '');
            var r = closet.mr.count('http.user.agent');
            closet.api.flows.report(pcap._id, q, r, function(data) {
                closet.render.table($root, data, opts);
            });
        }
    }, {
        name: 'servers',
        title: 'Web Servers',
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
                opts.order = { count: 'value', server: 'key' }[opts.order]
            }
            
            var q = 'flow.service:http*';
            var r = closet.mr.count('http.server');
            closet.api.flows.report(pcap._id, q, r, function(data) {
                closet.render.table($root, data, opts);
            });
        }
    }, {
        name: 'content',
        title: 'Content Types',
        options: function(pcap, opts, cb) {
            var q = 'flow.service:http*';
            closet.api.flows.servers(pcap._id, q, 0.0, pcap.index.about.duration, function(data) {
                var servers = $.map(data.rows, function(row) { return row.key; });
                opts.choice('server', '', { 'values': [''].concat(servers) });
                opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
                opts.choice('order', 'count', { values: [ 'count', 'type' ] });
                opts.boolean('descending', true);
                opts.boolean('normalize', true);
                cb();
            });
        },
        create: function(ctx, $root, pcap, opts) {
            opts = $.extend({}, opts, { value: 'count' });
            if (opts.order) {
                opts.order = { count: 'value', type: 'key' }[opts.order]
            }
            
            var q = 'flow.service:http*';
            var r = closet.mr.count('http.content.type');
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