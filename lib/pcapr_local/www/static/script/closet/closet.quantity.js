var closet = closet || {};
closet.quantity = (function() {
    return {
        bytes: function(size) {
        	if (size > 1024*1024) {
        		var mb = Math.round(size/1024/1024);
        		return mb + ' MB';
        	} else if (size > 1024) {
        		var kb = Math.round(size/1024);
        		return kb + ' KB';
        	} else {
        		return size + ' byte' + (size == 1 ? '' : 's');
        	}                
        },
        timespan: function(date) {
        	var today = new Date();
        	var seconds = (today.getTime() - date.getTime())/1000;

        	if (seconds < 30) {
        		return 'just now';
        	} else if (seconds < 90) {
        		return 'a minute ago';
        	} 

        	var minutes = seconds/60;
        	if (minutes < 20) {
        		return 'few minutes ago';
        	} else if (minutes < 45) {
        		return 'half hour ago';
        	} else if (minutes < 90) {
        		return 'an hour ago';
        	} 

        	var hours = minutes/60;
        	if (hours < today.getHours()) {
        		return 'earlier today';
        	} else if (hours < today.getHours() + 24) {
        		return 'yesterday';
        	} 

        	var days = hours/24;
        	if (days < today.getDay()) {
        		return 'earlier this week';
        	} else if (days < today.getDay() + 7) {
        		return 'last week';
        	} else if (days < 30) {
        		return 'a few weeks ago';
        	}

            var months = [
                "January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November",
                "December"
            ];
            var year = date.getFullYear();
            var month = date.getMonth();
            if (year == today.getFullYear()) {
                if (month == today.getMonth()) {
                    return 'earlier this month';
                } else if (month == today.getMonth() - 1) {
                    return 'last month';
                } else {
                    return 'last ' + months[month];
                }
            }

            return months[month] + ' ' + year;
        },
        count: function(value, singular, plural) {
        	return value + ' ' + (value === 1 ? singular : plural ? plural : singular + 's');                
        }
    };
}());
