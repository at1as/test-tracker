# test-tracker

gamma is a test tracking client written in Ruby and served by Sinatra. 

gamma gives you the ability to create projects, add test cases and save the execution history. 


## Users

gamma divides users into three privileges: "Read-Only", "Admin" and "Tester". The additional admin privilages allow for creation/deletion of users and change in access rights, as well as the ability to create and delete projects.


## Usage

Download the reposity here and launch gamma via

    $./gamma.rb

At the moment, mongo isn't packaged in the build, so mongo will need be launched from your system (for Mac OS enter into the command prompt /usr/local/bin/mongo). You will then need to create a database entitled 'gamma' with two collections 'users' and 'projects'.

Since no user exists by default, from the mongo prompt, enter:

	$use gamma
	$db.user.insert( { "email" : "<valid email address>", "privilege" : "admin", "password" : "<password>"})

This will create an admin user with which you can use to log in and access all of gamma's features.


## Dependencies

Requires a ruby installation (built and tested with 2.0) with the following Gems:
- 'sinatra' (the webserver)
- 'mongo' (the database)


## TODO

* Include a database with the appropriate structure
* Add ability to Edit test cases
* Add test import between projects
* Add ability to include attachments
* Add ability to delete test cases