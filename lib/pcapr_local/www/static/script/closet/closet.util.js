var closet = closet || {};
closet.util = (function() {
    return {
        escapeQuery: function(text) {
            if (typeof text !== 'string') { return text; }
            return text.replace(/([: ()%\-,=\\<>])/g, "\\$1");
        },
        escapeHTML: function(text) {
            if (typeof(text) !== 'string') { return text;}

            return text
                .replace(/&/g, '&amp;')
                .replace(/"/g, '&quot;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;');            
        },
        kvsToObject: function(kvs) {
            var obj = {};
            for (var i=0; i<kvs.length; ++i) {
                var kv = kvs[i];
                if (!obj.hasOwnProperty(kv.key)) {
                    obj[kv.key] = [];
                }
                obj[kv.key].push(kv.value);
            }
            return obj;
        },
        unique: function(array) {
            array.sort();
            for (var i=array.length-1; i>=0; --i) {
                var e = array[i];
                var en = array[i+1];
                if (en && e === en) {
                    array.splice(i+1, 1);
                }
            }
            return array;
        }
    }
}());