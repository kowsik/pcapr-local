var closet = closet || {};
closet.reports = closet.reports || [];
closet.reports.push({
    name: 'overview',
    title: 'Overview',
    items: [{
        name: 'services',
        title: 'Services',
        options: function(pcap, opts, cb) {
            opts.choice('filter', '', { values: [''].concat(['udp', 'tcp']) });
            opts.choice('limit', 10, { values: [ '', 10, 20, 50, 100 ] });
            opts.choice('order', 'count', { values: ['count', 'service'] });
            opts.boolean('descending', true);
            opts.boolean('normalize', true);
            cb();
        },
        create: function(ctx, $root, pcap, opts) {
            if (opts.order) {
                opts = $.extend({}, opts, {
                    order: { count: 'value', service: 'key' }[opts.order]
                });
            }
            
            if (opts.filter) {
                var q = 'flow.proto:' + (opts.filter === 'udp' ? 17 : 6);
                var r = closet.mr.count('flow.service');
                closet.api.flows.report(pcap._id, q, r, function(data) {
                    closet.render.table($root, data, opts);
                });
            } else {
                closet.api.field.terms(pcap._id, 'pkt.service', null, null, function(data) {
                    closet.render.table($root, data, opts);
                });
            }
        }
    }, {
        name: 'sizes',
        title: 'Packet Size',
        options: function(pcap, opts, cb) {
            pcap.index.services.sort();
            opts.choice('filter', '', { 'values': [''].concat(pcap.index.services) });
            opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
            opts.choice('order', 'count', { values: ['count', 'size'] });
            opts.boolean('descending', true);
            opts.boolean('normalize', true);
            cb();
        },
        create: function(ctx, $root, pcap, opts) {
            if (opts.order) {
                opts = $.extend({}, opts, {
                    order: { count: 'value', size: 'key' }[opts.order]
                });
            }
            
            if (opts.filter) {
                var q = 'pkt.service:' + opts.filter;
                var r = closet.mr.count('pkt.length');
                closet.api.packets.report(pcap._id, q, r, function(data) {
                    closet.render.table($root, data, opts);
                });
            } else {
                closet.api.field.terms(pcap._id, 'pkt.length', null, null, function(data) {
                    closet.render.table($root, data, opts);
                });
            }
        }
    }, {
        name: 'mac',
        title: 'MAC Addresses',
        apply: function(pcap, fields) {
            return fields.hasOwnProperty('eth.addr');
        },
        options: function(pcap, opts, cb) {
            pcap.index.services.sort();
            opts.choice('filter', '', { 'values': [''].concat(pcap.index.services) });
            opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
            opts.choice('order', 'count', { values: ['count', 'mac'] });
            opts.boolean('descending', true);
            opts.boolean('normalize', true);
            cb();
        },
        create: function(ctx, $root, pcap, opts) {
            if (opts.order) {
                opts = $.extend({}, opts, {
                    order: { count: 'value', mac: 'key' }[opts.order]
                });
            }
            
            if (opts.filter) {
                var q = 'pkt.service:' + opts.filter;
                var r = closet.mr.count('eth.addr');
                closet.api.packets.report(pcap._id, q, r, function(data) {
                    closet.render.table($root, data, opts);
                });                
            } else {
                closet.api.field.terms(pcap._id, 'eth.addr', null, null, function(data) {
                    closet.render.table($root, data, opts);
                });                
            }            
        }
    }, {
        name: 'ipv4',
        title: 'IPv4 Addresses',
        apply: function(pcap, fields) {
            return fields.hasOwnProperty('ip.host');
        },
        options: function(pcap, opts, cb) {
            pcap.index.services.sort();
            opts.choice('filter', '', { 'values': [''].concat(pcap.index.services) });
            opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
            opts.choice('order', 'count', { values: ['count', 'ip'] });
            opts.boolean('descending', true);
            opts.boolean('normalize', true);
            cb();
        },
        create: function(ctx, $root, pcap, opts) {
            if (opts.order) {
                opts = $.extend({}, opts, {
                    order: { count: 'value', ip: 'key' }[opts.order]
                });
            }
            
            // TODO: We'll need to have the ipv4/ipv6 type within each 
            // flow. This will allow us to rapidly scan for v4/v6 addresses
            // instead of running through all the packets
            var q = 'pkt.first:true ip.version:4';
            q = q + (opts.filter ? ' pkt.service:' + opts.filter : '')
            var r = closet.mr.count('ip.host');
            closet.api.packets.report(pcap._id, q, r, function(data) {
                closet.render.table($root, data, opts);
            });
        }
    }, {
        name: 'ipv6',
        title: 'IPv6 Addresses',
        apply: function(pcap, fields) {
            return fields.hasOwnProperty('ipv6.host');
        },
        options: function(pcap, opts, cb) {
            pcap.index.services.sort();
            opts.choice('filter', '', { 'values': [''].concat(pcap.index.services) });
            opts.choice('limit', 10, { 'values': [ '', 10, 20, 50, 100 ] });
            opts.choice('order', 'count', { values: ['count', 'ip'] });
            opts.boolean('descending', true);
            opts.boolean('normalize', true);
            cb();
        },
        create: function(ctx, $root, pcap, opts) {
            if (opts.order) {
                opts = $.extend({}, opts, {
                    order: { count: 'value', ip: 'key' }[opts.order]
                });
            }
            
            var q = 'pkt.first:true ip.version:6';
            q = q + (opts.filter ? ' pkt.service:' + opts.filter : '');
            var r = closet.mr.count('ipv6.host');
            closet.api.packets.report(pcap._id, q, r, function(data) {
                closet.render.table($root, data, opts);                
            });
        }
    }]
});