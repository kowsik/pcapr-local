var closet = closet || {};

(function($) {
closet.folders = (function() {
    var iconPlus = '<img class="icon" style="width:10px" src="/static/image/16x16/Plus.png"/>';
    var iconMinus = '<img class="icon" style="width:10px" src="/static/image/16x16/Minus.png"/>';
    var iconEmpty = '<img class="icon" style="width:10px" src="/static/image/16x16/Folder3.png"/>';
    
    var toggle = function($root) {
        var $children = $root.children('div.children');
        var $toggle = $root.children('a.toggle');
        if ($children.css('display') === 'none') {
            $children.css('display', '');
            $toggle.html(iconMinus);
        } else {
            $children.css('display', 'none');
            $toggle.html(iconPlus);
        }            
    };
            
    var addFolders = function($root, depth, cb) {
        var root = $root.data('path');
        var $children = $root.children('div.children');
        toggle($root);
        
        var url = '/pcaps/1/list?by=path';
        if (depth > 1) {
            var paths = root.split('/');
            var startkey = paths.concat([0]);
            var endkey = paths.concat([{}]);
            url += '&startkey=' + JSON.stringify(startkey);
            url += '&endkey=' + JSON.stringify(endkey);
        }
        
        $.ajax({
            url: url,
            data: { group_level: depth, limit: 20 },
            dataType: 'json',
            success: function(kvs) {
                if (kvs.rows.length === 0 && depth > 1) {
                    $root.find('a.toggle').replaceWith(iconEmpty);
                    return;
                }
                
                $.each(kvs.rows, function(_, kv) {
                    if (kv.key.length !== depth) { return; }
                    var path = kv.key.join('/');
                    $children.append(
                        '<div class="folder">' +
                            '<a class="toggle"/>&nbsp;' +
                            '<a class="link" title="' + path + '">' + kv.key[depth-1] + '</a>' +
                            '&nbsp;' +
                            '<sup style="font-size:smaller">' + kv.value + '</sup>' +
                            '<div class="children" style="margin-left:20px;display:none"/>' +
                        '</div>'
                    ).find('div.folder:last').data('path', path);
                });
                
                $children
                    .find('a.toggle').attr('href', 'javascript:void(0)')
                        .html('<img class="icon" style="width:10px" src="/static/image/16x16/Plus.png"/>')
                        .click(function() {
                            var folder = $(this).parent('div.folder');
                            var children = $(this).nextAll('div.children');
                            if (children.children().length === 0) {
                                addFolders(folder, depth+1, cb);
                            } else {
                                toggle(folder);
                            }
                        })
                    .end()
                    .find('a.link').attr('href', 'javascript:void(0)')
                        .click(function() {
                            cb($(this).parent('div.folder').data('path'));
                        });
            }
        });            
    };
    
    return {
        manage: function($root, cb) {
            var $f = $root.data('folders');
            if (!$f) {
                $f = $('<div class="folder" style="margin-top: 20px;margin-bottom:20px"><div class="children" style="display:none"/></div>');
                $f.data('path', '/');
                $root.data('folders', $f);
                addFolders($f, 1, cb);
            }
            
            $root.empty().append($f);            
        }
    };
}());
}(jQuery));
