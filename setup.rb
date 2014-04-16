#!/usr/bin/env ruby

# Run this script once, to initialize mongodb
# with the default user (admin@example.com)
require 'mongo'

# Spwan Mongo service, point to db directory
`mongod --dbpath ./db`

# Connect to Mongo service (default, localhost & port 27017)
# Will create "gamma" database if not present, or otherwise use existing
db = Mongo::Connection.new.db("gamma")

# Create Collections, if not present
unless db.collection_names.include? "users"
	users = db.create_collection('users')
end
unless db.collection_names.include? "projects"
	projects = db.create_collection('projects')
end

# Create Admin user
users.insert( { :email => "admin@example.com", :privilege => "admin", :password => "admin"})