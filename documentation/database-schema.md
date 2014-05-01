USERS

{
	{
		_id: “<unique - assigned by mongo> ”,
		“email” : “<valid email address> ”
		“privilege” : “<admin/tester/read-only>”
		“password” : “<string>”
	}
}



PROJECTS

{
	{
		_id: “<unique - assigned by mongo> ”
		“project” : “<unique project name>”,
		“shortname” : “<unique project shortname>”,
		“last-updated” : “<time updated>”
		“tests” :	[{
			“name” : “<test case name>”,
			“count”: <test count>
			“id”: “<shortname>-<count>”,
			“builds” : {				#build, tester, status, platform, environment
				[“<build>”, “<tester>”, “<pass/fail/blocked/not tested/deprecated>”,  [“<environment variable 1>”, “<environment variable 2>”] ],
			},
			“description” : “<description of test case>”,
			“name”: “<title of test case>”
			“steps”: [
				“<first step>”,
				“<second step>”,
				“<etc>”
			],
			“last-updated” : Time.now
		}]
	}
}
