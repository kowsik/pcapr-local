// ------------------------------------------------------------------------
// A set of map/reduce functions that's passed into xtractr for various
// types of reporting
// ------------------------------------------------------------------------
var closet = closet || {};
closet.mr = (function() {
    // Count the unique values of a field
    // The values of the field are used as keys during map and the reduction
    // is just the sum of each key
    function _count(field) {
        if (!field || typeof(field) !== 'string' || field.length === 0) {
            throw "Need a field name to count";
        }
        
        var source = function(_name) {
            return {
                map: function(_pf) {
                    _pf.values(_name, function(_value) {
	                    if (_value) {
	                        if (typeof(_value) === 'string' && _value.length > 1024) {
	                            _value = _value.slice(0,1024);
	                        }
	                        emit(_value, 1);
	                    }						
					});
                },
                reduce: function(_key, _values) {
                    return sum(_values);
                }
            };
        };
        
        source = '(' + source.toString() + ')(' + JSON.stringify(field.replace(/^(pkt|flow)\./, '')) + ')';
        return source;
    }
    
    // Count the matching objects, bucketized by the minute, hour, etc
    function _count_over_time(bucket) {
        bucket = Math.max(bucket || 60, 1);
        
        var source = function(_bucket) {
            return {
                map: function(_pf) {
                    var _key = parseInt((_pf.time/_bucket).toFixed(0), 0);
                    emit(_key, 1);
                },
                reduce: function(_key, _values) {
                    return sum(_values);
                }
            };
        };
        
        source = '(' + source.toString() + ')(' + JSON.stringify(bucket) + ')';
        return source;
    };    
    
    // Count the matching objects, bucketized over time, except the reduction
    // is by the specified field (think of stacked charts). For example:
    // pkt.service:(dns || http) > count_x_over_time('service')
    // will result in the count of dns, http packets for each of the time
    // buckets.
    function _count_x_over_time(field, bucket) {
        if (!field || typeof(field) !== 'string' || field.length === 0) {
            throw "Need a field name to count over";
        }
        
        bucket = Math.max(bucket || 60, 1);
        
        var source = function(_field, _bucket) {
            return {
                map: function(_pf) {
                    var _key = parseInt((_pf.time/_bucket).toFixed(0), 0);
					_pf.values(_field, function(_val) {
	                    if (_val) {
	                        if (typeof(_val) === 'string' && _val.length > 1024) {
	                            _val = _val.slice(0,1024);
	                        }
	                        var _obj = {};
	                        _obj[_val] = 1;
	                        emit(_key, _obj);
	                    }						
					});
                },
                reduce: function(_key, _values) {
                    var _rv = {};
                    for (var _i in _values) {
                        var _value = _values[_i];
                        for (var _k in _value) {
                            _rv[_k] = sum([ _rv[_k] || 0, _value[_k]]);
                        }
                    }
                    return _rv;
                }
            };
        };
        
        source = '(' + source.toString() + ')(' + JSON.stringify(field.replace(/^(pkt|flow)\./, '')) + ',' + JSON.stringify(bucket) + ')';
        return source;
    };
    
	// Compute the min, max count of the values vfield with the values of kfield
	// being the key used for the reduce
	function _minmax(kfield, vfield) {
        if (!kfield || typeof(kfield) !== 'string' || kfield.length === 0) {
            throw "Need a field name for the key";
        }
        
        if (!vfield || typeof(vfield) !== 'string' || vfield.length === 0) {
            throw "Need a field name for the value";
        }
		
		var source = function(_kfield, _vfield) {
			return {
				map: function(_pf) {
					var _key = _pf[_kfield];
					if (_key) {
                        if (typeof(_key) === 'string' && _key.length > 1024) {
                            _key = _key.slice(0,1024);
                        }
						_pf.values(_vfield, function(_val) {
							if (typeof(_val) === 'number') {
								emit(_key, { min: _val, max: _val, count: 1 });
							}
						});	
					}
				},
				reduce: function(_key, _values) {
                    var _rv = {};
                    for (var _i in _values) {
                        var _value = _values[_i];
						_rv.min = Math.min(_value.min, _rv.min || _value.min);
						_rv.max = Math.max(_value.max, _rv.max || _value.max);
						_rv.count = sum([ _rv.count || 0, _value.count]);
                    }
                    return _rv;					
				}
			};
		};
		
		var _kfs = JSON.stringify(kfield.replace(/^(pkt|flow)\./, ''));
		var _vfs = JSON.stringify(vfield.replace(/^(pkt|flow)\./, ''));
        source = '(' + source.toString() + ')(' + _kfs + ',' + _vfs + ')';
        return source;
	};
	
	// Sum the values of vfield, keyed by kfield
	function _sum(kfield, vfield) {
        if (!kfield || typeof(kfield) !== 'string' || kfield.length === 0) {
            throw "Need a field name for the key";
        }
        
        if (!vfield || typeof(vfield) !== 'string' || vfield.length === 0) {
            throw "Need a field name for the value";
        }
		
		var source = function(_kfield, _vfield) {
			return {
				map: function(_pf) {
					var _key = _pf[_kfield];
					if (_key) {
                        if (typeof(_key) === 'string' && _key.length > 1024) {
                            _key = _key.slice(0,1024);
                        }
						_pf.values(_vfield, function(_val) {
							if (typeof(_val) === 'number') {
								emit(_key, _val);
							}
						});	
					}
				},
				reduce: function(_key, _values) {
					return sum(_values);
				}
			};
		};
		
		var _kfs = JSON.stringify(kfield.replace(/^(pkt|flow)\./, ''));
		var _vfs = JSON.stringify(vfield.replace(/^(pkt|flow)\./, ''));
        source = '(' + source.toString() + ')(' + _kfs + ',' + _vfs + ')';
        return source;
	};
	
    // Sum the value of field, bucketized by the minute, hour, etc
    function _sum_over_time(field, bucket) {
        if (!field || typeof(field) !== 'string' || field.length === 0) {
            throw "Need a field name (with a numeric value) to sum over";
        }
        
        bucket = Math.max(bucket || 60, 1);
        
        var source = function(_name, _bucket) {
            return {
                map: function(_pf) {
					_pf.values(_name, function(_val) {
	                    if (typeof(_val) === 'number') {
	                        var _key = parseInt((_pf.time/_bucket).toFixed(0), 0);
	                        emit(_key, _val);
	                    }						
					});
                },
                reduce: function(_key, _values) {
                    return sum(_values);
                }
            };
        };
        
        source = '(' + source.toString() + ')(' + JSON.stringify(field.replace(/^(pkt|flow)\./, '')) + ',' + JSON.stringify(bucket) + ')';
        return source;
    };
	
    return {
        count: _count,
        count_over_time: _count_over_time,
        count_x_over_time: _count_x_over_time,
        minmax: _minmax,
        sum: _sum,
        sum_over_time: _sum_over_time
    };
}());