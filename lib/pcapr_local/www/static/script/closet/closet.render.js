var closet = closet || {};

(function($) {
closet.render = (function() {
    return {
        bars: function($root, kvs, opts) {
            opts = opts || {};
            opts.label = opts.label || '';
            
            var series = [];
            $.each(kvs.rows, function(i, row) {
                series.push([ row.key, row.value ]);
            });
            
    		var html = [];
    		html.push('<div style="margin-left: 20px; margin-bottom: 20px; width:800px; height:300px;"></div>');
    		$root = $root.html(html.join('')).find('div');
            $.plot($root, [ { label: opts.label, data: series } ], {
    			colors: [ '#e68000' ],
    			bars: { show: true },
    			grid: { borderWidth: 1, backgroundColor: { colors: ["#fff", "#eee"] } },
    			yaxis: {
    			    labelHeight: 4,
    			    tickFormatter: function(val, axis) {
    			        return val.toFixed(0);
    			    }
    			},
                legend: { show: true }
            });
        },
		cloud: function(kvs, cb) {
            var min = null, max = null;
            $.each(kvs.rows, function(i, kv) {
                min = Math.min(kv.value, min || kv.value);
                max = Math.max(kv.value, max || kv.value);
            });
            
            var minLog = Math.log(min);
            var maxLog = Math.log(max);
            var rangeLog = Math.max(1, maxLog - minLog);
            var minFontSize = 10;
            var maxFontSize = 50;
            
            var html = [];
            $.each(kvs.rows, function(i, kv) {
                var value = Math.max(1, kv.value);
                var ratio = (Math.log(value) - minLog) / rangeLog;
                var size = minFontSize + Math.round(((maxFontSize - minFontSize) * ratio));
                
				html = html.concat(cb(kv, size));
            });
            
			return html.join('');
		},
		// Options
		// {
		//     limit: <number>|''
		//     order: 'key'|'value'
		//     descending: true|false,
		//     normalize: true|false
		//     value: 'count' || 'bytes'
		// }
		table: function($root, kvs, opts, cb, morecb) {
			opts = opts || {};
			opts.limit = opts.limit ? opts.limit : (opts.limit === '' ? kvs.rows.length : 10);
			opts.order = opts.order || 'value';
			if (opts.descending === undefined) {
				opts.descending = true;
			}
			
	        kvs.rows.sort(function(a, b) { 
				var _a = opts.descending ? a[opts.order] : b[opts.order];
				var _b = opts.descending ? b[opts.order] : a[opts.order];
				return _b > _a ? 1 : _b < _a ? -1 : 0; 
			});
			
	        var top = kvs.rows.slice(0, opts.limit);
            var max = 0;
            var total = 0;
            $.each(kvs.rows, function(i, kv) {
                max = Math.max(kv.value, max);
                total += kv.value;
            });
			
			var html = [];
			if (kvs.rows.length > 0) {
				html.push('<table style="margin-bottom: 20px">');
				$.each(top, function(i, kv) {
                    var width = Math.max((kv.value/max*400).toFixed(0), 1);
					
					if (typeof(kv.key) === 'string' && kv.key.length > 96) {
						kv.key = kv.key.slice(0, 95) + '*';
					}
					
					var value = kv.value;
					if (opts.normalize) {
					    value = (Math.ceil(kv.value/total*100) + '%');
					} else {
					    if (opts.value && opts.value === 'bytes') {
					        value = closet.quantity.bytes(value);
					    }
					}
					
					html.push('<tr>');
					html.push('<td align="right">' + value + '</td>');
					html.push('<td>');
					html.push('<div style="position:absolute;margin-left:10px">');
					html.push(cb ? cb(kv) : closet.util.escapeHTML(kv.key));
					html.push('</div>');
                    html.push('<img src="/static/image/bar-orange.gif" style="opacity:1.0;border:none;height:18px;width:' + width + 'px"/>');
					html.push('</td>');
					html.push('</tr>');
				});
				html.push('</table>');
				
				if (kvs.rows.length > top.length && morecb) {
					html.push(morecb());
				}	
			} else {
				html.push("<span class=info>Hmm...Your query didn't seem to match anything.</span>");
			}
			
			$root.html(html.join(''));			
		},
		minmax: function($root, kvs, opts, cb, morecb) {
			opts = opts || {};
			opts.limit = opts.limit ? opts.limit : (opts.limit === '' ? kvs.rows.length : 10);
			if (opts.order !== 'min' && opts.order !== 'max' && opts.order !== 'count' && opts.order !== 'spread') {
				opts.order = 'spread';
			}
			
			if (opts.descending === undefined) {
				opts.descending = true;
			}
			
			// Compute the min-of-min and max-of-max as well as the spread
			// between the max and the min				
			var minOfMin;
            var maxOfMax;
			var integer = true;
            $.each(kvs.rows, function(i, kv) {
                minOfMin = Math.min(kv.value.min, minOfMin || kv.value.min);
                maxOfMax = Math.max(kv.value.max, maxOfMax || kv.value.max);
				kv.value.spread = Math.max(kv.value.max - kv.value.min, 0);
				if (kv.value.min.toString().indexOf('.') > 0) {
					integer = false;
				} else if (kv.value.max.toString().indexOf('.') > 0) {
					integer = false;
				}
            });
			var range = Math.max(maxOfMax - minOfMin, 1);
			
			// Sort based on the user-defined criteria
	        kvs.rows.sort(function(a, b) { 
				var _a = opts.descending ? a.value[opts.order] : b.value[opts.order];
				var _b = opts.descending ? b.value[opts.order] : a.value[opts.order];
				return _b > _a ? 1 : _b < _a ? -1 : 0;
			});
			
			var html = [];
			if (kvs.rows.length > 0) {
				html.push('<table style="margin-bottom: 20px">');
				html.push('<thead style="font-weight:bold">');
				html.push('<tr>');
				html.push('<td>Count</td>');
				html.push('<td>Min</td>');
				html.push('<td>Max</td>');
				html.push('<td>Spread</td>');
				html.push('</tr>');
				html.push('</thead>');
				html.push('<tbody>');
		        var top = kvs.rows.slice(0, opts.limit);
				$.each(top, function(i, kv) {
					var width = Math.max(((kv.value.max - kv.value.min)*400/range).toFixed(0), 2);
					var margin = ((kv.value.min - minOfMin)*400/range).toFixed(0);
					html.push('<tr>');
					html.push('<td>' + kv.value.count + '</td>');
					html.push('<td>' + kv.value.min.toFixed(integer ? 0 : 4) + '</td>');
					html.push('<td>' + kv.value.max.toFixed(integer ? 0 : 4) + '</td>');
					html.push('<td>');
					if (typeof(kv.key) === 'string' && kv.key.length > 96) {
						kv.key = kv.key.slice(0, 95) + '*';
					}
					html.push('<div style="position:absolute;margin-left:10px">');
					html.push(cb ? cb(kv) : closet.util.escapeHTML(kv.key));
					html.push('</div>');
                    html.push('<img src="/static/image/bar-orange.gif" style="border:none;height:18px;width:' + width + 'px;margin-left:' + margin + 'px"/>');
					html.push('</td>');
					html.push('</tr>');
				});
				html.push('</tbody>');
				html.push('</table>');
				
				if (kvs.rows.length > top.length && morecb) {
					html.push(morecb());
				}
			} else {
				html.push("<span class=info>Hmm...Your query didn't seem to match anything.</span>");
			}
			
			$root.html(html.join(''));
		}			
    };
}());
}(jQuery));
