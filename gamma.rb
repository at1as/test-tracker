#!/usr/bin/env ruby

require 'sinatra'
require 'mongo'
require 'json/ext'
include Mongo

use Rack::Session::Cookie, :key => 'rack.session',
	:path => '/',
	:expire_after => 14400,
	:secret => "jasonsSuperSecret!",
	:username => nil,
	:access => nil

helpers do
	include Rack::Utils
	alias_method :h, :escape_html
end

configure do
	@processes = []
	launch_cmd = 'mongod --dbpath ./db'
	@processes << spawn(launch_cmd, :out => '/dev/null')
	sleep 1
	DB = Mongo::Connection.new.db("gamma", :pool_size => 5, :timeout => 5)
	$gammaUsers = DB.collection("users")
	$gammaProjects = DB.collection("projects")
end

def admin 
	return env["rack.session"][:access] == "admin"
end

def tester		#returns valid for tester and any user with greater than tester rights (as a superset)
	return (env["rack.session"][:access] == "admin" or env["rack.session"][:access] == "tester")
end

def readonly	#returns valid for readonly and any user with greater than readonly rights (as a superset)
	return (env["rack.session"][:access] == "admin" or env["rack.session"][:access] == "tester" or env["rack.session"][:access] == "read-only")
end

get '/?' do
	erb :index
end

post '/?' do
	@passwordFail = false
	@userexists = $gammaUsers.find(:email => params[:username], :password => params[:password]).to_a
	if @userexists.length() > 0
		env["rack.session"][:secret] = rand(36**16).to_s(36) 	#random string 16 characters long
		env["rack.session"][:username] = params[:username]
		@userPrivilege = $gammaUsers.find( {:email => params[:username]}, { :fields => { "privilege" => 1, "_id" => 0}}).to_a
		@userPrivilege[0].each do |key, value|
			env["rack.session"][:access] = value
		end
		redirect '/projects.html'
	else
		@passwordFail = true
		erb :index
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
	if readonly
		erb :me
	else
		redirect '/'
	end
end

get '/projects.html' do
	if readonly
		@projects = $gammaProjects.find( {}, { :fields => { "project" => 1, "_id" => 0 }}).to_a
		erb :projects
	else
		redirect '/'
	end
end

get '/users.html' do
	if admin
		@users = $gammaUsers.find( {}, { :fields => { "email" => 1, "privilege" => 1, "_id" => 0 }}).to_a
		erb :users
	else
		erb :'not-allowed'
	end
end

get '/admin-panel.html' do
	if admin
		@projects = $gammaProjects.find( {}, { :fields => { "project" => 1, "_id" => 0 }}).to_a
		erb :'admin-panel'
	else
		erb :'not-allowed'
	end
end

post '/api/users' do
	if admin
		if params[:action] == 'create'
			if $gammaUsers.find(:email => params[:createUserEmail]).to_a.length > 0
				puts "duplicate!"
			else 
				# create new uniquely named user
				$gammaUsers.insert( { :email => "#{params[:createUserEmail]}", :privilege => "#{params[:createUserPrivilege]}", :password => "#{params[:createUserPwd]}"})
			end
		elsif params[:action] == 'delete'
			# delete user (todo: this is necessarily unique, so findone will speed up execution time)
			$gammaUsers.find( {:email => params[:user] }).each do |remove_doc| 
				$gammaUsers.remove(remove_doc)
			end
		elsif params[:action] == 'update'
			#update user privilage. Chosen from select, so assuming user does exist.	
			$gammaUsers.update( { :email => params[:user] }, { "$set" => { :privilege => params[:privilege] }})
		end
		redirect '/users.html'
	end
end

get '/projects/:project' do
	if readonly
		@lastUpdated = $gammaProjects.find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "last-updated" => 1}}).to_a
		@testCount = $gammaProjects.find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "testCount" => 1 }}).to_a
		@prefix = $gammaProjects.find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "shortname" => 1 }}).to_a
		@perTestDetails = $gammaProjects.find( { :project => params[:project].capitalize}, { :fields => { "tests.count" => 1, "tests.name" => 1, "_id" => 0 }} ).to_a[0].to_hash["tests"].to_a
		erb :project
	else
		redirect '/'
	end
end

get '/projects/:project/tests' do
	if readonly
		@prefix = $gammaProjects.find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "shortname" => 1 }}).to_a
		@perTestDetails = $gammaProjects.find( { :project => params[:project].capitalize}, { :fields => { "tests.count" => 1, "tests.name" => 1, "_id" => 0 }} ).to_a[0].to_hash["tests"].to_a
		erb :'project-tests'
	else
		redirect '/'
	end
end

post '/api/projects/:project/tests' do
	if tester
		@maxSteps = params[:totalSteps]
		@prefix = $gammaProjects.find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "shortname" => 1 }}).to_a[0].to_hash["shortname"]
		@steps = []
		@stepsIterator = 0
		#@maxSteps are the total number of steps created, however some intermediate steps may be deleted by user prior to submit. Hence this loop
		@maxSteps.to_i.times do
			@stepsIterator += 1
			if params[:"step#{@stepsIterator}"]
				@steps << params[:"step#{@stepsIterator}"]
			end
		end
		#find current number of tests, increment number by one assign to the new test below
		@testCount = $gammaProjects.find( { :project => params[:project].capitalize}, :fields => { "testCount" => 1, "_id" => 0 }).to_a[0].to_hash["testCount"].to_i + 1
		#Create new testcase
		$gammaProjects.update( { :project => params[:project].capitalize }, { '$push' => { 'tests' => { 'name' => params[:testname], 'description' => params[:testdescription], 'count' => @testCount, 'builds' => [], 
			'environment' => [], 'last-updated' => Time.new.inspect, 'steps' => @steps }}})
		#Update total test cound in database
		$gammaProjects.update( { :project => params[:project].capitalize }, { "$inc" => {'testCount' => 1 }}) 
		puts params[:platform2]
	end
	redirect '/projects/' + params[:project] + '/tests'
end

get '/projects/:project/tests/:shortcode-:count' do
	if tester
		@prefix = $gammaProjects.find( { :project => params[:project].capitalize }, { :fields => { "_id" => 0, "shortname" => 1 }}).to_a
		@perTestDetails = $gammaProjects.find( { :project => params[:project].capitalize}, { :fields => { "tests.count" => 1, "tests.name" => 1, "_id" => 0 }} ).to_a[0].to_hash["tests"].to_a
		@testDetails = $gammaProjects.find( { :project => params[:project].capitalize },  :fields => { 'tests' => { '$elemMatch' => {"count" => params[:count].to_i }},  "_id" => 0}).to_a[0].to_hash["tests"][0]
		erb :'project-test-view'
	else
		redirect '/'
	end
end

post '/api/projects' do
	if readonly
		if params[:action] == "create"
			if $gammaProjects.find(:project => params[:createProjectName].capitalize ).to_a.length > 0 or $gammaProjects.find(:shortname => params[:createProjectCode].upcase).to_a.length > 0
				#todo: notify front end that project name already exists
				puts "duplicate!"
			else
				#create new project with unique name
				$gammaProjects.insert( { :project => params[:createProjectName].capitalize, :shortname => "#{params[:createProjectCode]}".upcase, :testCount => 0, :tests => [], :"last-updated" => Time.new.inspect })
			end
		elsif params[:action] == 'delete'	#Delete Project
			#todo: this is necessarily unique, so findone will speed up execution time
			$gammaProjects.find( {:project => params[:projectToDelete] }).each do |remove_doc|
                $gammaProjects.remove(remove_doc)
			end
		end
	end
	redirect '/projects.html'
end

post '/api/projects/:project/tests/:shortcode-:count/platforms' do
	if tester
		if params[:action] == "create"
			#todo: ensure unique platform
			#create new single testing platform 
			$gammaProjects.update( { :project => params[:project].capitalize, "tests.count" => params[:count].to_i }, { '$push' => { 'tests.$.environment' => params[:newPlatform]}}, :upsert => true)
		elsif params[:action] == "delete"
			#delete single platform from list of testing platforms
			$gammaProjects.update( { :project => params[:project].capitalize, "tests.count" => params[:count].to_i }, { '$pull' => { 'tests.$.environment' => params[:deleteID]}}, :upsert => true)
		end
		redirect '/projects/' + params[:project] + "/tests/" + params[:shortcode] + "-" + params[:count]
	end
end

post '/api/projects/:project/tests/:shortcode-:count/execution' do
	if tester
		@currentEnv = $gammaProjects.find( { :project => params[:project].capitalize, "tests.count" => params[:count].to_i },  :fields => { "tests.environment" => 1, "_id" => 0 }).to_a[0].to_hash["tests"][0]["environment"]
		#add new execution to the database
		$gammaProjects.update( { :project => params[:project].capitalize, "tests.count" => params[:count].to_i }, 
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