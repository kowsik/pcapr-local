var closet = closet || {};

(function($) {
closet.api = (function() {
    
var throbber = function() {
    var span = null; 
    var count = 0;
    return {
        show: function(text) {
            span = span || $('span.throbber');
            span.text(text || 'hang on...');
            if (count++ === 0) {
                span.show();
            }
        },
        hide: function() { 
            span = span || $('span.throbber');
            if (--count <= 0) { 
                span.hide(); 
                count = 0;
            } 
        }
    };
}();

return {
    PAGE_SIZE: 20,
    call: function(url, query, scb, ecb) {
        throbber.show();
        $.jsonp({
            url: url,
            data: query,
			dataFilter: function(data) {
				return JSON.parse(JSON.stringify(data));
			},
			callbackParameter: 'callback',
            success: function(data) {
                scb(data);
            },
            complete: function(xopts, status) { 
                throbber.hide(); 
				if (status !== 'success' && ecb) {
				    ecb();
				}
            }
        });
    },
    pcaps: {
        list_by_date: function(query, scb, ecb) {
            var url = '/pcaps/1/list?by=date';
            var _query = {
                include_docs: true,
                limit: closet.api.PAGE_SIZE+1,
                descending: true                
            };
            
            if (query) {
                if (query.startkey) { _query.startkey = unescape(query.startkey); }
                if (query.startkey_docid) { _query.startkey_docid = query.startkey_docid; }
                if (query.limit) { _query.limit = query.limit; }                
            }
            
            closet.api.call(url, _query, scb, ecb);
        },
        // Expect 'dirs' to be an array of path components
        list_by_dir: function(dirs, query, scb, ecb) {
            dirs = dirs.concat([]);
            if (dirs.length === 1 && dirs[0].length === 0) { dirs.pop(); }
            dirs.unshift(dirs.length);
                        
            var url = '/pcaps/1/list?by=directory&endkey=' + JSON.stringify(dirs);
            var _query = {
                reduce: false,
                include_docs: true,
                limit: closet.api.PAGE_SIZE+1,
                descending: true
            };
            
            if (query) {
                _query.startkey = query.startkey ? unescape(query.startkey) : JSON.stringify(dirs.concat([""]));
                if (query.startkey_docid) { _query.startkey_docid = query.startkey_docid; }
                if (query.limit) { _query.limit = query.limit; }                
            }
            
            closet.api.call(url, _query, scb, ecb);            
        },
        list_by_keyword: function(keyword, query, scb, ecb) {
            var url = '/pcaps/1/list?by=keyword';
            var _query = {
                startkey: '["' + keyword + '\\u9999"]',
                endkey: '["' + keyword + '"]',
                reduce: false,
                include_docs: true,
                limit: closet.api.PAGE_SIZE,
                descending: true
            };
            
            if (query) {
                if (query.limit) { _query.limit = query.limit; }                
            }
            
            closet.api.call(url, _query, scb, ecb);            
        },
        list_by_service: function(service, query, scb, ecb) {
            var url = '/pcaps/1/list?by=service&endkey=[' + service + ']';
            var _query = {
                reduce: false,
                include_docs: true,
                limit: closet.api.PAGE_SIZE+1,
                descending: true
            };
            
            if (query) {
                _query.startkey = query.startkey ? unescape(query.startkey) : ('[' + service + ',""]');
                if (query.startkey_docid) { _query.startkey_docid = query.startkey_docid; }
                if (query.limit) { _query.limit = query.limit; }                
            }
            
            closet.api.call(url, _query, scb, ecb);
        },
        list_by_status: function(status, query, scb, ecb) {
            var url = '/pcaps/1/list?by=status&endkey=[' + status + ']';
            var _query = {
                reduce: false,
                include_docs: true,
                limit: closet.api.PAGE_SIZE+1,
                descending: true                
            };
            
            if (query) {
                _query.startkey = query.startkey ? unescape(query.startkey) : ('[' + status + ',""]');
                if (query.startkey_docid) { _query.startkey_docid = query.startkey_docid; }
                if (query.limit) { _query.limit = query.limit; }                
            }
            
            closet.api.call(url, _query, scb, ecb);
        },
        services: function(scb, ecb) {
            var url = '/pcaps/1/list?by=service';
            closet.api.call(url, { group_level: 1 }, scb, ecb);
        },
        statistics: function(scb, ecb) {
            var url = '/pcaps/1/statistics';
            closet.api.call(url, null, scb, ecb);
        }
    },
    pcap: {
        about: function(pcap, scb, ecb) {
            var url = '/pcaps/1/about/' + pcap;
            closet.api.call(url, null, scb, ecb);
        },
        remove: function(pcap, scb, ecb) {
            var url = '/pcaps/1/remove/' + pcap;
            closet.api.call(url, null, scb, ecb);            
        }
    },
    fields: {
        list: function(pcap, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/fields';
            closet.api.call(url, null, scb, ecb);            
        }
    },
	field: {
		terms: function(pcap, field, start, limit, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/field/' + field + '/terms';
            var query = { };
            if (start !== null && start !== undefined) { query.start = start; }
            if (limit != null && limit !== undefined) { query.limit = limit; }
			closet.api.call(url, query, scb);
		}
	},
    flows: {
        list: function(pcap, query, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/flows';
            closet.api.call(url, query, scb, ecb);
        },
        report: function(pcap, query, report, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/flows/report';
            closet.api.call(url, { q: query, r: report }, scb, ecb);            
        },
        clients: function(pcap, query, start, end, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/flows/clients';
            var query = { q: query, start: start, end: end };
            closet.api.call(url, query, scb, ecb);
        },
        servers: function(pcap, query, start, end, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/flows/servers';
            var query = { q: query, start: start, end: end };
            closet.api.call(url, query, scb, ecb);
        },
        services: function(pcap, query, start, end, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/flows/services';
            var query = { q: query, start: start, end: end };
            closet.api.call(url, query, scb, ecb);
        }
    },
    flow: {
        about: function(pcap, id, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/flows';
            var query = { q: 'flow.id:' + id, limit: 1 };
            closet.api.call(url, query, function(data) {
                if (data.rows.length === 1) {
                    scb(data.rows[0]);
                } else {
                    (ecb || function() {})();
                }
            }, ecb);
        }
    },
    packets: {
        fields: function(pcap, query, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/packets/fields';
            closet.api.call(url, query, scb, ecb);
        },
        list: function(pcap, query, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/packets';
            closet.api.call(url, query, scb, ecb);
        },
        report: function(pcap, query, report, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/packets/report';
            closet.api.call(url, { q: query, r: report }, scb, ecb);            
        }
    },
    packet: {
        about: function(pcap, packet, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/packet/' + packet + '/about';
            closet.api.call(url, null, scb, ecb);            
        },
        pdml: function(pcap, packet, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/packet/' + packet + '/pdml';
            closet.api.call(url, null, scb, ecb);
        },
        bytes: function(pcap, packet, scb, ecb) {
            var url = '/pcaps/1/pcap/' + pcap + '/api/packet/' + packet + '/bytes';
            closet.api.call(url, null, scb, ecb);
        }
    }    
}; 
}());
}(jQuery));
