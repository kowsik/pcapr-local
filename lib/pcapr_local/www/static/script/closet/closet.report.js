var closet = closet || {};
(function($) {
closet.report = (function() {
    return {
        load: function(ctx, $root, pcap, cb) {
            closet.api.fields.list(pcap._id, function(fields) {
                var fieldMap = {};
                $.each(fields, function(i, v) { fieldMap[v] = true; });
                
                closet.reports.list = closet.reports.list || [];
                var html = [ '<option>Pick one</option>' ];
                $.each(closet.reports, function(_, category) {
                    if (category.hasOwnProperty('apply') === false || category.apply(pcap, fieldMap)) {
                        var html2 = [];
                        $.each(category.items, function(index, report) {
                            report.category = category.name;
                            report.index = index;
                            if (report.hasOwnProperty('apply') === false || report.apply(pcap, fieldMap)) {
                                html2.push('<option id="' + closet.reports.list.length + '">' + report.title + '</option>');
                                closet.reports.list.push(report);
                            }
                        });

                        if (html2.length > 0) {
                            html.push('<optgroup label="' + category.title + '">');
                            html = html.concat(html2);
                            html.push('</optgroup>');                        
                        }                        
                    }
                });

                var $report = $root.find('div.report');
                var $select = $root.find('select.reports');
                var $showonload = $root.find('span.showonload');

                $select.html(html.join('')).change(function() {
                    var id = $(this).find('option:selected').attr('id');
                    if (id) {
                        var index = parseInt(id, 10);
                        var report = closet.reports.list[index];
                        ctx.app.setLocation('#/browse/report/' + pcap._id + '/' + report.category + '/' + report.name);
                    }                    
                });
                $showonload.css('display', '');
                $report.empty();
                if (cb) { cb(); }
            });
        },
        create: function(ctx, $root, pcap, category, report, opts) {
            $.each(closet.reports, function(_, c) {
                if (c.name === category) {
                    $.each(c.items, function(_, r) {
                        if (r.name === report) {
                            var $report = $root.find('div.report');
                            var $title = $root.find('h3.title').html(c.title + '|' + r.title);
                            var $settings = $root.find('div.settings');
                            var $toggler = $settings.find('a.toggler');
                            var $options = $settings.find('div.options');
                            
                            $report.html('<span class="throbber">generating...</span>');
                            if (r.options) {
                                closet.options.create(function(maker) {
                                    r.options(pcap, maker, function() {
                                        var $maker = maker.build(opts, function(_opts) {
                                            $report.html('<span class="throbber">generating...</span>');
                                            r.create(ctx, $report, pcap, _opts);
                                        });
                                        $settings.css('display', '');
                                        $toggler.click(function() { $options.slideToggle(); });
                                        $options.append($maker);
                                        r.create(ctx, $report, pcap, maker.reconcile(opts));
                                    });
                                });
                            } else {
                                r.create(ctx, $report, pcap, opts);                                
                            }
                            return false;
                        }
                    });
                    return false;
                }
            });
        }
    };
}());
}(jQuery));