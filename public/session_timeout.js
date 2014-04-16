/* 	
	Will redirect to login page on cookie expiration
	This will prevent the user from submitting data with an
	expired cookie (and thus losing their submission).
	Interval (5000 ms) must match gamma.rb (:expire_after => <interval>)
*/
setTimeout("top.location.href = '/'", 3000);