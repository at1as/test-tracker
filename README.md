# test-tracker

gamma is a test tracking client written in Ruby and served by Sinatra. 

It gives you the ability to create new projects, add test and remove cases to them, and track their execution history. Stay tuned, there's more coming! 


## Users

gamma divides users into three privileges: "Read-Only", "Admin" and "Tester". The additional admin privilages allow for creation/deletion of users (and to change their access rights), as well as the ability to create and delete projects.


## Usage

Download the reposity here and launch the setup script:

    $./setup.rb
    
This will launch mongo, and create the gamma database with the admin user. Please ensure your system has mongodb installed prior to running. This script only needs to be run once.

Next, launch the program!

    $./gamma.rb

Navigate to localhost:4567 and log in with the default credentials created by setup.rb. Ctrl+C will end the program, and the contents of the database will be preserved for the next time the program is launched.


## Dependencies

Requires a ruby installation (built and tested with 2.0) with the following Gems:
- 'sinatra' (tested with 1.4.4)
- 'mongo' (tested with 2.4.8)

This also requires that your system has mongodb installed (this is done easily with yum or apt-get on linux, or homebrew on Mac OS).


## Limitations

If you are the only user with admin privilages and you delete yourself, run setup.rb again to create the default user


## TODO

* Consider adding ability to Edit test cases
* Add test import between projects
* Add ability to include attachments
* Add ability to delete test cases (and/or render them inactive)
