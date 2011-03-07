/*
 *	jquery.suggest 1.1 - 2007-08-06
 *	
 *	Uses code and techniques from following libraries:
 *	1. http://www.dyve.net/jquery/?autocomplete
 *	2. http://dev.jquery.com/browser/trunk/plugins/interface/iautocompleter.js	
 *
 *	All the new stuff written by Peter Vulgaris (www.vulgarisoip.com)	
 *	Feel free to do whatever you want with this file
 *
 */

(function($) {
	$.fn.caret = function(options,opt2){
		var start,end,t=this[0];
		if(typeof options==="object" && typeof options.start==="number" && typeof options.end==="number") {
			start=options.start;
			end=options.end;
		} else if(typeof options==="number" && typeof opt2==="number"){
			start=options;
			end=opt2;
		} else if(typeof options==="string"){
			if ((start = t.value.indexOf(options)) > -1) {
				end = start + options.length;
			}
			else {
				start = null;
			}
		} else if(Object.prototype.toString.call(options)==="[object RegExp]"){
			var re=options.exec(t.value);
			if(re) {
				start=re.index;
				end=start+re[0].length;
			}
		}
		if(typeof start!="undefined"){
			if($.browser.msie){
				var selRange = this[0].createTextRange();
				selRange.collapse(true);
				selRange.moveStart('character', start);
				selRange.moveEnd('character', end-start);
				selRange.select();
			} else {
				this[0].selectionStart=start;
				this[0].selectionEnd=end;
			}
			this[0].focus();
			return this;
		} else {
			var s, e;
			if($.browser.msie){
				var val = this.val();
				var range = document.selection.createRange().duplicate();
				range.moveEnd("character", val.length);
				s = (range.text == "" ? val.length : val.lastIndexOf(range.text));
				range = document.selection.createRange().duplicate();
				range.moveStart("character", -val.length);
				e = range.text.length;				
			} else {
				s=t.selectionStart;
				e=t.selectionEnd;
			}
			var te=t.value.substring(s,e);
			return {start:s,end:e,text:te,replace:function(st){
				t.value = t.value.substring(0,s)+st+t.value.substring(e,t.value.length);
			}};
		}
		return this;
	};
	
	$.suggest = function(input, options) {
		var $input = $(input).attr("autocomplete", "off");
		var $results = $(document.createElement("ul"));
		var timeout = false;		// hold timeout ID for suggestion results to appear	
		var prevLength = 0;			// last recorded length of $input.val()
		var cache = [];				// cache MRU list
		var cacheSize = 0;			// size of cache in chars (bytes?)
		
		var $em = $(document.createElement('div')).css({
			left: 0,
			top: 0,
			position: 'absolute',
			visibility: 'hidden',
			border: 'none',
			padding: '0px'
		}).appendTo('body');
				
		$results.addClass(options.resultsClass).appendTo('body');

		var resetPosition = function() {
			// requires jquery.dimension plugin
			var offset = $input.offset();
			$results.css({
				top: (offset.top + input.offsetHeight) + 'px',
				left: offset.left + 'px'
			});
		};
		
		var processKey = function(e) {
			// handling up/down/escape requires results to be visible
			// handling enter/tab requires that AND a result to be selected
			if ((/27$|38$|40$/.test(e.keyCode) && $results.is(':visible')) ||
				(/^13$|^9$/.test(e.keyCode) && getCurrentResult())) {
				
				if (e.preventDefault) {
					e.preventDefault();
				}
				
				if (e.stopPropagation) {
					e.stopPropagation();
				}

				e.cancelBubble = true;
				e.returnValue = false;
			
				switch(e.keyCode) {
					case 38: // up
						prevResult();
						break;
			
					case 40: // down
						nextResult();
						break;

					case 9:  // tab
					case 13: // return
						selectCurrentResult();
						break;
						
					case 27: //	escape
						$results.hide();
						break;
				}				
			} 
			else if ($input.val().length != prevLength) {
				if (timeout) {
					clearTimeout(timeout);
				}
				timeout = setTimeout(suggest, options.delay);
				prevLength = $input.val().length;
			}			
		};
				
		var suggest = function() {
			var q = $input.val();

			$results.hide();
			if (q.length >= options.minchars) {
				var obj = options.source(q, $input.caret(), function(_obj) {
					displayItems(_obj);
				});
				
				if (obj) {
					displayItems(obj);					
				}
			}
		};
		
		var displayItems = function(obj) {
			if ($.isArray(obj)) {
				obj = { items: items };
			}
				
			if (!obj || !obj.items || !obj.items.length) {
				return;
			}
			
			var html = '';
			for (var i = 0; i < obj.items.length; i++) {
				html += '<li id="' + i + '">' + obj.items[i] + '</li>';
			}

			$results.html(html);
			if (options.complete) {
				var caret = $input.caret();
				var text = $input.val().substring(0, caret.end);
				var width = $em.text(text).offset().width;
				var offset = $input.offset();
				$results.css({
					top: (offset.top + input.offsetHeight) + 'px',
					left: (offset.left + width) + 'px'
				});
				$results.find('li').each(function() {
					$.data(this, 'jquery.suggest', obj);
				});
			}
			$results.show();
			
			$results
				.children('li')
				.mouseover(function() {
					$results.children('li').removeClass(options.selectClass);
					$(this).addClass(options.selectClass);
				})
				.click(function(e) {
					e.preventDefault(); 
					e.stopPropagation();
					selectCurrentResult();
				});						
		};
		
		var getCurrentResult = function() {		
			if (!$results.is(':visible')) {
				return false;
			}
		
			var $currentResult = $results.children('li.' + options.selectClass);
			
			if (!$currentResult.length) {
				$currentResult = false;
			}
				
			return $currentResult;
		};
		
		var selectCurrentResult = function() {		
			$currentResult = getCurrentResult();
		
			if ($currentResult) {
				if (options.complete) {
					var obj = $.data($currentResult.get(0), 'jquery.suggest');
					var id = parseInt($currentResult.attr('id'), 10);
					var text = obj.complete ? obj.complete[id] : obj.items[id];
					$input.caret({ start: obj.start, end: obj.end });
					$input.caret().replace(text);
					var pos = obj.start + text.length;
					$input.caret({ start: pos, end: pos });
				} else {
					$input.val($currentResult.text());					
				}
				$results.hide();
				
				if (options.onSelect) {
					options.onSelect.apply($input[0]);
				}					
			}		
		};
		
		var nextResult = function() {		
			$currentResult = getCurrentResult();
		
			if ($currentResult) {
				$currentResult.removeClass(options.selectClass).next().addClass(options.selectClass);
			}
			else {
				$results.children('li:first-child').addClass(options.selectClass);
			}		
		};
		
		var prevResult = function() {		
			$currentResult = getCurrentResult();
		
			if ($currentResult) {
				$currentResult.removeClass(options.selectClass).prev().addClass(options.selectClass);
			}
			else {
				$results.children('li:last-child').addClass(options.selectClass);
			}		
		};
		
		resetPosition();
		$(window)
			.load(resetPosition)		// just in case user is changing size of page while loading
			.resize(resetPosition);

		$input.blur(function() {
			setTimeout(function() { $results.hide(); }, 200);
		});
				
		// help IE users if possible
		try {
			$results.bgiframe();
		} catch(e) { }

		// I really hate browser detection, but I don't see any other way
		if ($.browser.mozilla) {
			$input.keypress(processKey); // onkeypress repeats arrow keys in Mozilla/Opera
		}
		else {
			$input.keydown(processKey); // onkeydown repeats arrow keys in IE/Safari
		}
	};
	
	$.fn.suggest = function(source, options) {	
		if (!source) {
			return;
		}
	
		options = options || {};
		options.source = source;
		options.delay = options.delay || 100;
		options.complete = options.complete || false;
		options.resultsClass = options.resultsClass || 'ac_results';
		options.selectClass = options.selectClass || 'ac_over';
		options.matchClass = options.matchClass || 'ac_match';
		options.minchars = options.minchars || 2;
		options.delimiter = options.delimiter || '\n';
		options.onSelect = options.onSelect || false;
		options.maxCacheSize = options.maxCacheSize || 65536;

		this.each(function() {
			$.suggest(this, options);
		});

		return this;		
	};	
})(jQuery);

