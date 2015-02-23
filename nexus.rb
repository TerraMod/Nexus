#!/usr/bin/env ruby

require 'sinatra/base'
require 'parseconfig'
require 'sqlite3'
require 'json'
require 'securerandom'
require 'rest-client'
require 'thread'
require 'pi_piper'
Dir["./modules/*.rb"].each {|file| require file }
include PiPiper


#
# The Nexus Sinatra application serves hardware modules over a web api authenticated by TLS client certificates.
# 
# The modules/ directory contains Ruby classes that implement a piece of hardware.  See https://wiki.terramod.hkparker.com/ for information on module development.
# The ssl/ directory contains certificates used to authenticate calls to the TerraMod controller as well as keys used to autheticate requets from the controller.
#

class Nexus < Sinatra::Base

	# Log is for errors encoutered on start up or with using modules, not access logging

	def self.log(file, line, fatal=false)
		file.write "[#{Time.new.strftime("%Y-%m-%d %H:%M:%S")}] #{line}\n"
		exit 1 if fatal
	end

	configure do
		
		#
		# Every time the Nexus runs, it parses nexus.conf and populates a new SQLite database containing modules
		# A rest client is created to do TLS client certificate authentication against the controller
		# A thread is started to read from a queue and post the data to the controller with this client
		# The queue is given to all modules that implement send_event, so they can send callbacks
		#
		
		log_file = File.open("./nexus.log","a")
		log(log_file, "NexusServer starting...")
		
		
		begin
			config = ParseConfig.new "./nexus.conf"
			db_flie = "/tmp/nexus_modules.db"
			File.delete(db_flie) if File.exist?(db_flie)
			db = SQLite3::Database.new db_flie
			db.execute "CREATE TABLE Modules(uuid TEXT, name TEXT, class TEXT, room TEXT, hardware TEXT, last_state TEXT, UNIQUE(uuid));"
		rescue => e
			log(log_file, "Unable to start NexusServer: #{e}", true)
		end
		
		# Event queue recieves hashes to post to the controller.  See JSON Event wiki.
		event_queue = Queue.new
		modules = {}
		
		config.params.each do |k, v|
			if v.class == Hash
				modules[k] = v
				uuid = k
				name = v['name']
				type = v['type']
				room = v['room']
				hardware = v['hardware']
				db.execute "INSERT INTO Modules VALUES(?,?,?,?,?,?);", [uuid, name, type, room, hardware, "none"]
				log(log_file, "Parsed module #{uuid}: name => #{name}, room => #{room}, type => #{type}, hardware => #{hardware}")
				module_class = Module.const_get(type)
				module_class.clear_state(hardware) if module_class.methods.include? :clear_state
				module_class.watch_hardware(uuid, hardware, event_queue, db) if module_class.methods.include? :watch_hardware
			else
				set k.to_sym, v												# set all top level options in the configuration file in the class's settings
			end
		end
        
		event_queue << {"type" => "ModuleReport", "uuid" => settings.uuid, "data" => modules}
		
		authenticated_client = RestClient::Resource.new("http://#{settings.controller}/event_reciever")#,
                         #:ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read('./ssl/controller_client.pem')),
                         #:ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read('./ssl/controller_client.key'), ''),
                         #:verify_ssl       =>  OpenSSL::SSL::VERIFY_NONE)
		
		Thread.new{
			loop{
				data = event_queue.pop
				#puts data
				authenticated_client.post(data.to_json)
			}
		}
		
		set :db, db
		set :log_file, log_file
	
	end

	get '/modules' do
	
		# Create a hash of the modules in the database, serialize to JSON
	
		modules = {}
		row = settings.db.execute "SELECT * FROM Modules;"
		row.each do |mod|
			modules[mod[0]] = {
				"name" => mod[1],
				"class" => mod[2],
				"room" => mod[3],
				"hardware" => mod[4]
			}
		end
		return modules.to_json
	end
	
	get '/query/:uuid' do |uuid|
	
		begin
			last_state = settings.db.execute "SELECT last_state FROM Modules WHERE uuid=?;", [uuid]
			body last_state[0]
		rescue => e
			Nexus.log(settings.log_file, "Error: db lookup error: #{e}")
			status 501
			return
		end
		
		status 200
	end
	
	get '/set/:uuid/:state' do |uuid, state|
	
		# Look up the uuid in the database, return 404 if it doesn't exist
		row = settings.db.execute "SELECT class,hardware FROM Modules WHERE uuid=?;", [uuid]
		if row.size == 0
			Nexus.log(settings.log_file, "Error: requested uuid #{uuid} was not found in the database")
			status 404
			return 
		end
		
		# Get the class name from the module's configuration.  See if it exists in the namespace and assign it to 'type'
		mod = row[0]
		begin
			type = Module.const_get(mod[0])
		rescue NameError => e
			Nexus.log(settings.log_file, "Error: hardware configured with class name #{mod[0]} but no class found")
			status 501
			return
		end
		
		# Make sure this hardware class actually allows for setting a state by checking for the '.set_state' method
		if !type.methods.include? :set_state
			Nexus.log(settings.log_file, "Error: module class #{mod[0]} does not implement set_state")
			status 501
			return 
		end
		
		# Attempt to set the state of the hardware
		hardware = mod[1]
		begin
			body type.set_state(hardware, state)
		rescue => e
			Nexus.log(settings.log_file, "Error: hardware set error: #{e}")
		end
		
		status 200
		
	end
	
end
