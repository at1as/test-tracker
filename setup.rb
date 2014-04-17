#!/usr/bin/env ruby

# Run this script once, to initialize mongodb with the default user (admin@example.com)
require 'mongo'

# Variables
@processes = []
host, port = 'localhost', 27017

# Spwan Mongo service, point to db directory
launch_cmd = 'mongod --dbpath ./db'
@processes << spawn(launch_cmd, :out => '/dev/null')
puts "\n>> Mongod process started"
sleep 1

# Connect to Mongo service Will create "gamma" database if not present, or otherwise use existing
db ||= Mongo::Connection.new(host, port).db("gamma")
puts ">> Connected to #{host}:#{port} and using gamma database"

# Create Collections, if not present
unless db.collection_names.include? "users"
	users = db.create_collection('users')
	puts ">> 'users' collection created"
else 
	puts ">> 'users' collection already exists"
end
unless db.collection_names.include? "projects"
	projects = db.create_collection('projects')
	puts ">> 'projects' collection created"
else
	puts ">> 'projects' collection already exists"
end

# Create Admin user
if db["users"].find_one( { :email => "admin@example.com", :privilege => "admin", :password => "admin" }).nil?
	db["users"].insert( { :email => "admin@example.com", :privilege => "admin", :password => "admin"})
	puts ">> Admin user created (username: 'admin@example.com', password: 'admin')"
else
	puts ">> Admin user already existed (username: 'admin@example.com', password: 'admin')"
end
sleep 1

# Shutdown
puts ">> Shutting Down ... \n\n"
@processes.each do |pid|
	Process.kill 'KILL', pid
end

exit 0