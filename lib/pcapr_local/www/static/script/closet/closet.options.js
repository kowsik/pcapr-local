var closet = closet || {};
(function($) {
var Maker = function() { this.options = []; };


Maker.Boolean = function(args) { $.extend(this, args); };
Maker.Boolean.prototype.build = function(ctx, html) {
    ctx.add(this, this.name, this.value);
    html.push('<tr>');
    html.push('<td><label for="' + this.id + '">' + this.label + '</label></td>');
    html.push('<td><input id="' + this.id + '" class="boolean" type="checkbox"' + (this.value ? 'checked' : '') + '/></td>');
    html.push('<tr>');        
};
Maker.Boolean.prototype.coerce = function(value) {
    this.value = value === 'true' || value === '1' || value === true || value === 1;
};
Maker.prototype.boolean = function(name, value, args) {
    args = args || {};
    this.options.push(new Maker.Boolean({
        type: 'boolean',
        name:  name,
        label: args.label || name,
        value: value
    }));
};


Maker.Choice = function(args) { $.extend(this, args); };
Maker.Choice.prototype.build = function(ctx, html) {
    var self = this;
    ctx.add(this, this.name, this.value);
    html.push('<tr>');
    html.push('<td>' + this.label + '</td>');
    html.push('<td><select class="choice" id="' + this.id + '">');
    $.each(this.values, function(i, v) {
        html.push('<option ' + (v.toString() === self.value.toString() ? 'selected' : '') + '>' + v + '</option>');
    });
    html.push('</select></td>');        
};
Maker.Choice.prototype.coerce = function(value) {
    var self = this;
    $.each(this.values, function(_, v) {
        if (typeof v === 'string' && v === value) {
            self.value = value;
        } else if (typeof v === 'number' && v.toString() === value) {
            self.value = parseInt(value, 10);
        }
    });
};
Maker.prototype.choice = function(name, value, args) {
    args = args || {};
    this.options.push(new Maker.Choice({
        type: 'choice',
        name:  name,
        label: args.label || name,
        value: value,
        values: args.values || [ value ]
    }));
};


Maker.Group = function(args) { $.extend(this, args); };
Maker.Group.prototype.build = function(ctx, html) {
    html.push('<tr class="group">');
    html.push('<td colspan="2">' + this.label + '</td>');
    html.push('</tr>');
    
    ctx.push(this.name);
    $.each(this.options, function(i, v) {
        v.build(ctx, html);
    });
    ctx.pop();        
};
// Intentionally no coerce function here, since group is not a leaf entity
Maker.prototype.group = function(name, args, cb) {
    args = args || {};
    var group = new Maker.Group({
        type: 'group',
        name: name,
        label: args.label || name,
        options: []
    });

    this.options.push(group);

    var _opts = this.options;
    this.options = group.options;
    cb(maker);
    this.options = _opts;
};


Maker.Number = function(args) { $.extend(this, args); };
Maker.Number.prototype.build = function(ctx, html) {
    ctx.add(this, this.name, this.value);
    html.push('<tr>');
    html.push('<td>' + this.label + '</td>');
    html.push('<td><input id="' + this.id + '" class="number" type="text" value="' + this.value + '"/></td>');
    html.push('<tr>');
};
Maker.Number.prototype.coerce = function(value) {
    if (/^\d+$/.test(value)) {
        this.value = parseInt(value, 10);
    }
};
Maker.prototype.number = function(name, value, args) {
    args = args || {};
    this.options.push(new Maker.Number({
        type: 'number',
        name:  name,
        label: args.label || name,
        value: value,
        required: args.required || true,
        min:   args.min,
        max:   args.max
    }));
},

Maker.Select = function(args) { $.extend(this, args); };
Maker.Select.prototype.build = function(ctx, html) {
    var self = this;
    ctx.push(this.name);
    
    $.each(this.values, function(i, v) {
        ctx.add(self, 'select', i);
        return false;
    });
    
    html.push('<tr>');
    html.push('<td>' + this.label + '</td>');
    html.push('<td>');
    html.push('<select id="' + this.id + '" class="select">');
    $.each(this.values, function(i, v) {
        html.push('<option>' + i + '</option>');
    });
    html.push('</select>');
    html.push('</td>');
    html.push('</tr>');
    html.push('</tbody>');
    
    var count = 0;
    $.each(this.values, function(i, v) {
        html.push('<tbody class="when" select="' + this.id + '" id="' + i + '" style="display:' + ((count++ === 0) ? 'table-row-group' : 'none') + '; padding-left: 20px">');
        ctx.push(i);
        $.each(v, function(i_, v_) {
            v_.build(ctx, html);
        });
        ctx.pop();            
        html.push('</tbody>');
    });
    ctx.pop();
    
    html.push('<tbody>');        
};
Maker.Select.prototype.coerce = function(value) {
    var self = this;
    $.each(self.values, function(_, v) {
        if (v === value) {
            self.value = value;
            return false;
        }
    });
};
Maker.prototype.select = function(name, values, args) {
    var self = this;
    args = args || {};
    var select = new Maker.Select({
        type: 'select',
        name: name,
        label: args.label || name,
        values: {}
    });

    this.options.push(select);
    $.each(values, function(key, value) {
        select.values[key] = [];
        if (value) {
            var _opts = self.options;
            self.options = select.values[key];
            value(self);
            self.options = _opts;
        }
    });
};


Maker.String = function(args) { $.extend(this, args); };
Maker.String.prototype.build = function(ctx, element) {
    ctx.add(e, this.name, this.value);
    html.push('<tr>');
    html.push('<td>' + this.label + '</td>');
    html.push('<td><input id="' + this.id + '" class="string" type="text" value="' + this.value + '"/></td>');
    html.push('<tr>');        
};
Maker.String.prototype.coerce = function(value) {
    this.value = value;
};
Maker.prototype.string = function(name, value, args) {
    args = args || {};
    this.options.push(new Maker.String({
        type: 'string',
        name: name,
        label: args.label || name,
        value: value,
        required: args.required || false
    }));
};


Maker.Text = function(args) { $.extend(this, args); };
Maker.String.prototype.build = function(ctx, element) {
    ctx.add(this, this.name, this.value);
    html.push('<tr>');
    html.push('<td>' + this.label + '</td>');
    html.push('<td><textarea id="' + this.id + '" class="text" rows="' + this.rows + '" cols="' + this.cols + '">' + this.value + '</textarea></td>');
    html.push('<tr>');        
};
Maker.Text.prototype.coerce = function(value) {
    this.value = value;
};
Maker.prototype.text = function(name, value, args) {
    args = args || {};
    this.options.push(new Maker.Text({
        type: 'text',
        name: name,
        label: args.label || name,
        value: value,
        rows: args.rows || 8,
        cols: args.cols || 64
    }));
};


Maker.prototype.build = function(kvs, changecb) {
    this.reconcile(kvs);
    
    var ctx = (function() {
        var nextId = 0;
        var map = {};
        var opts = {};
        var stack = [ opts ];
        return {
            add: function(e, key, value) {
                e.id = nextId++;
                e.opts = stack[stack.length-1];
                e.opts[key] = value;
                map[e.id.toString()] = e;
            },
            push: function(name) {
                var _opts = stack[stack.length-1];
                _opts[name] = {};
                stack.push(_opts[name]);
            },
            pop: function() {
                stack.pop();
            },
            opts: opts,
            map: map
        };
    }());
    
    var html = [ '<table>' ];
    html.push('<tbody>');
    $.each(this.options, function(_, e) {
        e.build(ctx, html);
    });
    html.push('</tbody>');
    html.push('</table>');
    
    return $(html.join('')).
        // opt_boolean
        find('input.boolean').click(function() {
            var id = $(this).attr('id');
            var e = ctx.map[id];
            e.opts[e.name] = $(this).is(':checked');
            changecb(ctx.opts);
        }).end().
        
        // opt_choice
        find('select.choice').change(function() {
            var id = $(this).attr('id');
            var e = ctx.map[id];
            e.opts[e.name] = $(this).val();
            changecb(ctx.opts);
        }).end().
        
        // opt_number
        find('input.number').change(function() {
            var id = $(this).attr('id');
            var e = ctx.map[id];
            var value = parseInt($(this).val(), 0);
            value = Math.max(e.min || value, value);
            value = Math.min(e.max || value, value);
            e.opts[e.name] = value;
            changecb(ctx.opts);
        }).end().
        
        // opt_select
        find('select.select').change(function() {
            var id = $(this).attr('id');
            var when = $(this).find('option:selected').val();
            ctx.map[id].opts.select = when;
            $(this).parents('tbody').nextAll('tbody[select=' + id + ']').
                css('display', 'none').
                filter('#' + when + '.when').
                css('display', 'table-row-group');
                changecb(ctx.opts);
        }).end().
        
        // opt_string, opt_text
        find('input.string,textarea.text').change(function() {
            var id = $(this).attr('id');
            var e = ctx.map[id];
            e.opts[e.name] = $(this).val();
            changecb(ctx.opts);
        }).end();            
};


Maker.prototype.reconcile = function(kvs) {
    kvs = kvs || {};
    
    var _flatten = function(obj, prefix, opts) {
        prefix = (prefix && prefix.length > 0) ? (prefix + '.') : '';
        $.each(opts, function(_, opt) {
            if (opt.type === 'group') {
                _keys(obj, prefix + opt.name, opts);
            } else {
                obj[prefix + opt.name] = opt;
            }
        });
        return obj;
    };
    
    var _options = _flatten({}, null, this.options);
    var coerced = {};
    for (var key in _options) {
        if (_options.hasOwnProperty(key)) {
            if (kvs.hasOwnProperty(key)) {
                _options[key].coerce(kvs[key]);                
            }
            coerced[key] = _options[key].value;
        }
    }
    
    return coerced;
};


closet.options = (function(cb) {
    return {
        create: function(cb) {
            var maker = new Maker();
            cb(maker);
            return maker;            
        }
    };
}());
}(jQuery));