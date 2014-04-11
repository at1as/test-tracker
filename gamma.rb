#!/usr/bin/env ruby

require 'sinatra'
require 'mongo'
include Mongo

use Rack::Session::Cookie, :key => 'rack.session',
	:path => '/',
	:expire_after => 12000,
	:secret => "jasonsSuperSecret!",
	:username => nil,
	:access => nil

helpers do
	include Rack::Utils
	alias_method :h, :escape_html
end

configure do
	DB = Mongo::Connection.new.db("gamma", :pool_size => 5, :timeout => 5)
end

get '/?' do
	erb :index
end

post '/?' do
	@passwordFail = false
	@userexists = DB.collection("users").find(:email => params[:username], :password => params[:password]).to_a
	if @userexists.length() > 0
		env["rack.session"][:secret] = rand(36**16).to_s(36) #random string 16 characters long
		env["rack.session"][:username] = params[:username]
		@userPrivilege = DB.collection("users").find( {:email => params[:username]}, { :fields => { "privilege" => 1, "_id" => 0}}).to_a
		@userPrivilege[0].each do |key, value|
			env["rack.session"][:access] = value
		end
		redirect '/projects.html'
	else
		@passwordFail = true
		erb :'index'
	end
end

get '/password-reset.html' do
	erb :'password-reset'
end

post '/password-reset.html' do
	@resetSent = true
	redirect '/'
end

get '/not-allowed.html' do
	erb :'not-allowed'
end

get '/me.html' do
	if env["rack.session"][:secret]
		erb :me
	else
		redirect '/'
	end
end

get '/projects.html' do
	if env["rack.session"][:secret]
		@projects = DB.collection("projects").find( {}, { :fields => { "project" => 1, "_id" => 0 }}).to_a
		erb :projects
	else
		redirect '/'
	end
end

get '/users.html' do
	if env["rack.session"][:access] == "admin"
		@users = DB.collection("users").find( {}, { :fields => { "email" => 1, "privilege" => 1, "_id" => 0 }}).to_a
		erb :users
	else
		erb :'not-allowed'
	end
end

get '/admin-panel.html' do
	if env["rack.session"][:access] == "admin" 
		@projects = DB.collection("projects").find( {}, { :fields => { "project" => 1, "_id" => 0 }}).to_a
		erb :'admin-panel'
	else
		erb :'not-allowed'
	end
end

post '/api/users' do
	if env["rack.session"][:access] == "admin"
		if params[:action] == 'create'
			if DB.collection("users").find(:email => params[:createUserEmail]).to_a.length > 0
				puts "duplicate!"
			else
				# create new uniquely named user
				DB.collection("users").insert( { :email => "#{params[:createUserEmail]}", :privilege => "#{params[:createUserPrivilege]}", :password => "#{params[:createUserPwd]}"})
			end
		elsif params[:action] == 'delete'
			# todo: this is necessarily unique, so findone will speed up execution time
			# delete user
			DB.collection("users").find( {:email => params[:user] }).each do |remove_doc| 
				DB.collection("users").remove(remove_doc)
			end
		elsif params[:action] == 'update'
			#update user privilage. Chosen from select, so assuming user does exist.	
			DB.collection("users").update( { :email => params[:user] }, { "$set" => { :privilege => params[:privilege] }})
		end
		redirect '/users.html'
	end
end

get '/projects/:project' do
	if env["rack.session"][:access] == "admin" or  env["rack.session"][:access] == "tester" or env["rack.session"][:access] == "read-only"
		@lastUpdated = DB.collection("projects").find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "last-updated" => 1}}).to_a
		@testCount = DB.collection("projects").find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "testCount" => 1 }}).to_a
		@prefix = DB.collection("projects").find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "shortname" => 1 }}).to_a
		@perTestDetails = DB.collection("projects").find( { :project => params[:project].capitalize}, { :fields => { "tests.count" => 1, "tests.name" => 1, "_id" => 0 }} ).to_a[0].to_hash["tests"].to_a
		erb :project
	else
		redirect '/'
	end
end

get '/projects/:project/tests' do
	if env["rack.session"][:access] == "admin" or env["rack.session"][:access] == "tester" or env["rack.session"][:access] == "read-only"
		@prefix = DB.collection("projects").find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "shortname" => 1 }}).to_a
		@perTestDetails = DB.collection("projects").find( { :project => params[:project].capitalize}, { :fields => { "tests.count" => 1, "tests.name" => 1, "_id" => 0 }} ).to_a[0].to_hash["tests"].to_a
		#puts @perTestDetails
		erb :'project-tests'
	else
		redirect '/'
	end
end

post '/api/projects/:project/tests' do
	if env["rack.session"][:access] == "admin" or env["rack.session"][:access] == "tester"
		@maxSteps = params[:totalSteps]
		@prefix = DB.collection("projects").find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "shortname" => 1 }}).to_a[0].to_hash["shortname"]
		@steps = []
		@stepsIterator = 0
		#@maxSteps are the total number of steps created, however some may be deleted. Hence this loop
		@maxSteps.to_i.times do
			@stepsIterator += 1
			if params[:"step#{@stepsIterator}"]
				@steps << params[:"step#{@stepsIterator}"]
			end
		end
		#find current number of tests, increment number by one assign to the new test below
		@testCount = DB.collection("projects").find( { :project => params[:project].capitalize}, :fields => { "testCount" => 1, "_id" => 0 }).to_a[0].to_hash["testCount"].to_i + 1
		#Create new testcase
		DB.collection("projects").update( { :project => params[:project].capitalize }, { '$push' => { 'tests' => { 'name' => params[:testname], 'description' => params[:testdescription], 'count' => @testCount, 'builds' => [], 
			'environment' => [], 'last-updated' => Time.new.inspect, 'steps' => @steps }}})
		#Update total test cound in database
		DB.collection("projects").update( { :project => params[:project].capitalize }, { "$inc" => {'testCount' => 1 }}) 
		puts params[:platform2]
	end
	redirect '/projects/' + params[:project] + '/tests'
end

get '/projects/:project/tests/:shortcode-:count' do
	if env["rack.session"][:access] == "admin" or env["rack.session"][:access] == "tester" or env["rack.session"][:access] == "read-only"
		@prefix = DB.collection("projects").find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "shortname" => 1 }}).to_a
		@perTestDetails = DB.collection("projects").find( { :project => params[:project].capitalize}, { :fields => { "tests.count" => 1, "tests.name" => 1, "_id" => 0 }} ).to_a[0].to_hash["tests"].to_a
		@testDetails = DB.collection("projects").find( { :project => params[:project].capitalize },  :fields => { 'tests' => { '$elemMatch' => {"count" => params[:count].to_i }},  "_id" => 0}).to_a[0].to_hash["tests"][0]
		erb :'project-test-view'
	else
		redirect '/'
	end
end

post '/api/projects' do
	if env["rack.session"][:access] == "admin" or  env["rack.session"][:access] == "tester" or env["rack.session"][:access] == "read-only"
		if params[:action] == "create"
			if DB.collection("projects").find(:project => params[:createProjectName].capitalize ).to_a.length > 0 or DB.collection("projects").find(:shortname => params[:createProjectCode].upcase).to_a.length > 0
				#todo: notify front end that project name already exists
				puts "duplicate!"
			else
				#create new project with unique name
				DB.collection("projects").insert( { :project => params[:createProjectName].capitalize, :shortname => "#{params[:createProjectCode]}".upcase, :testCount => 0, :tests => [], :"last-updated" => Time.new.inspect })
			end
		elsif params[:action] == 'delete'
			#todo: this is necessarily unique, so findone will speed up execution time
			#delete project
			DB.collection("projects").find( {:project => params[:projectToDelete] }).each do |remove_doc|
                DB.collection("projects").remove(remove_doc)
			end
		end
	end
	redirect '/projects.html'
end

post '/api/projects/:project/tests/:shortcode-:count/platforms' do
	if env["rack.session"][:access] == "admin" or  env["rack.session"][:access] == "tester"
		if params[:action] == "create"
			#todo: ensure unique platform
			#create new single testing platform 
			DB.collection("projects").update( { :project => params[:project].capitalize, "tests.count" => params[:count].to_i }, { '$push' => { 'tests.$.environment' => params[:newPlatform]}}, :upsert => true)
		elsif params[:action] == "delete"
			#delete single platform from list of testing platforms
			DB.collection("projects").update( { :project => params[:project].capitalize, "tests.count" => params[:count].to_i }, { '$pull' => { 'tests.$.environment' => params[:deleteID]}}, :upsert => true)
		end
		redirect '/projects/' + params[:project] + "/tests/" + params[:shortcode] + "-" + params[:count]
	end
end

post '/api/projects/:project/tests/:shortcode-:count/execution' do
	if env["rack.session"][:access] == "admin" or  env["rack.session"][:access] == "tester"
		@currentEnv = DB.collection("projects").find( { :project => params[:project].capitalize, "tests.count" => params[:count].to_i },  :fields => { "tests.environment" => 1, "_id" => 0 }).to_a[0].to_hash["tests"][0]["environment"]#[0]["environment"]
		#add new execution to the database
		DB.collection("projects").update( { :project => params[:project].capitalize, "tests.count" => params[:count].to_i }, 
			{ '$push' => { 'tests.$.builds' => { 'build' => params[:'build-number'], 'tester' => env["rack.session"][:username], 'result' => params[:'test-result'], 'executed' => Time.new.inspect, 'environment' => @currentEnv }}}) 
	end
	redirect '/projects/' + params[:project] + "/tests/" + params[:shortcode] + "-" + params[:count]
end

post '/logout' do
	env["rack.session"][:secret] = nil
	env["rack.session"][:username] = nil
	env["rack.session"][:access] = nil
	redirect '/'
end
