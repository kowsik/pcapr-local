var closet = closet || {};

(function($) {
closet.load = (function() {
    $('ul.tab a').click(function() {
        var id = $(this).attr('id');
        $('ul.tab li.active').removeClass('active').end();
        $(this).parent('li').addClass('active');
    });
    
    var refresh = function(ctx) {
        closet.api.pcaps.statistics(function(stats) {
            ctx.render('/templates/statistics.template', { stats: stats }, function(content) {
                $('div.statistics').html(content);
            });            
        });
    };
    
    var browse = function(ctx, data) {
        ctx.render('/templates/browse.template', data, function(content) {
            ctx.$element().html(content).find('a.remove').click(function() {
                var $self = $(this);
                var id = $self.attr('id');
                if (confirm('Are you sure you want to delete this pcap and the index?')) {
                    closet.api.pcap.remove(id, function(result) {
                        if (result.ok) {
                            $self.parents('li.l0').css('background', '#DD1122').fadeOut(function() {
                                $self.remove();
                            });
                        }
                    });
                }
            });
        });
    };
    
    var app = $.sammy(function() {
        this.element_selector = $('div.browse-tab');
        this.use(Sammy.Template);
        
        // 1. Select the appropriate tab on click
        // 2. Update the statistics on each click
        this.before(/^#\/(create|browse|services|folders)/, function(ctx) {
            var id = RegExp.$1;
            $('ul.tab a#' + id).click();
            
            // Especially for the folders, we need to keep the contents
            // around since it contains the expanded/collapsed states of 
            // the subfolders as well as all of the events.
            if (ctx.$element().data('closet.detach')) {
                ctx.$element().data('closet.detach', false);
                ctx.$element().contents().detach();                
            }
            ctx.$element().html('<div><p/><span class="throbber">hang on</span><p/></div>');
            refresh(ctx);
        });
        
        // Create scenarios from HAR files
        this.get('#/create', function(ctx) {
            ctx.render('/templates/har.upload.template', {}, function(content) {
                ctx.$element().html(content);
                closet.create.har(ctx);
            });
        });
                
        // Browse the pcaps by date (and handle paging)
        this.get('#/browse', function(ctx) {
            var path = ctx.path.replace(/\?.*$/, '');
            closet.api.pcaps.list_by_date({
                startkey: ctx.params.nextkey,
                startkey_docid: ctx.params.nextid,
            }, function(pcaps) {
                browse(ctx, { path: path, pcaps: pcaps });
            });
        });
        
        // Filter the pcaps by service (and handle paging)
        this.get(/^#\/browse\/service\/(.*)/, function(ctx) {
            var path = ctx.path.replace(/\?.*$/, '');
            var service = JSON.stringify(ctx.params.splat[0]);
            closet.api.pcaps.list_by_service(service, {
                startkey: ctx.params.nextkey,
                startkey_docid: ctx.params.nextid
            }, function(pcaps) {
                pcaps.filter = true;
                browse(ctx, { path: path, pcaps: pcaps });
            });
        });
        
        // Filter the pcaps by status (and handle paging)
        this.get('#/browse/status/:name', function(ctx) {
            var path = ctx.path.replace(/\?.*$/, '');
            var status = JSON.stringify(ctx.params.name);
            closet.api.pcaps.list_by_status(status, {
                startkey: ctx.params.nextkey,
                startkey_docid: ctx.params.nextid
            }, function(pcaps) {
                pcaps.filter = true;
                browse(ctx, { path: path, pcaps: pcaps });
            });
        });
        
        // Filter the pcaps by directory path (and handle paging)
        this.get(/^#\/browse\/dir\/(.*)/, function(ctx) {
            var path = ctx.path.replace(/\?.*$/, '');            
            var dirs = ctx.params.splat[0].split('/');            
            closet.api.pcaps.list_by_dir(dirs, {
                startkey: ctx.params.nextkey,
                startkey_docid: ctx.params.nextid
            }, function(pcaps) {
                pcaps.filter = true;
                browse(ctx, { path: path, pcaps: pcaps });
            });
        });
        
        // Filter the pcaps by keyword
        this.get('#/browse/keyword/:name', function(ctx) {
            var path = ctx.path.replace(/\?.*$/, '');            
            closet.api.pcaps.list_by_keyword(ctx.params.name, null, function(pcaps) {
                pcaps.filter = true;
                browse(ctx, { path: path, pcaps: pcaps });
            });
        });
        
        // View a given pcap
        this.get('#/browse/pcap/:pcap', function(ctx) {
            closet.api.pcap.about(ctx.params.pcap, function(pcap) {
                ctx.render('/templates/pcap.template', { pcap: pcap }, function(content) {
                    var $reports = ctx.swap(content).find('div.reports');
                    closet.report.load(ctx, $reports, pcap);
                });
            });
        });
        
        // Report on a given pcap (with optional filters and other settings)
        this.get('#/browse/report/:pcap/:category/:report', function(ctx) {
            closet.api.pcap.about(ctx.params.pcap, function(pcap) {
                ctx.render('/templates/pcap.template', { pcap: pcap }, function(content) {
                    var $reports = ctx.swap(content).find('div.reports');
                    var category = ctx.params.category;
                    var report = ctx.params.report;
                    closet.report.load(ctx, $reports, pcap, function() {
                        closet.report.create(ctx, $reports, pcap, category, report, ctx.params);                        
                    });
                });
            });
        });
        
        // Generate a scenario for a given flow
        // this.get('#/browse/pcap/:pcap/flow/:id', function(ctx) {
        //     var pcap = { _id: ctx.params.pcap };
        //     closet.scenario(ctx.$element(), pcap, ctx.params.id);
        // });
        
        // Expand/collapse folders
        this.get('#/folders', function(ctx) {
            ctx.$element().data('closet.detach', true);
            closet.folders.manage(ctx.$element(), function(path) {
                app.setLocation('#/browse/dir/' + path);
            });
        });
        
        // Show services across all pcaps
        this.get('#/services', function(ctx) {
            closet.api.pcaps.services(function(kvs) {
                ctx.partial('/templates/browse.services.template', { kvs: kvs });                
            });
        });
    });
    
    (function() {
        var timerId;
        var lastVal = '';
        var timer = function() {
            app.setLocation(lastVal.length < 2 ? '#/browse' : ('#/browse/keyword/' + lastVal));
        };
        
        $('input#search').keyup(function() {
            lastVal = $(this).val();
            if (timerId) { clearTimeout(timerId); }
            timerId = setTimeout(timer, 250);
        });        
    }());
    
    app.run('#/browse');
});
}(jQuery));