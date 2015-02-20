#!/usr/bin/env ruby

require 'sinatra/base'
require 'parseconfig'
require 'sqlite3'
require 'json'
#require 'pi_piper'
#include PiPiper

Dir["./modules/*.rb"].each {|file| require file }

class Nexus < Sinatra::Base

	def self.report_modules(db, controller)
		modules = {}
		row = db.execute "SELECT * FROM Modules;"
		row.each do |mod|
			modules[mod[0]] = {
				"name" => mod[1],
				"class" => mod[2],
				"room" => mod[3],
				"hardware" => mod[4]
			}
		end
		return modules.to_json	# post these to the controller, secured to the event reciever...
	end
	
	def self.log(file, line, fatal=false)
		file.write "[#{Time.new.strftime("%Y-%m-%d %H:%M:%S")}] #{line}\n"
		exit 1 if fatal
	end

	configure do
		
		log_file = File.open("./nexus.log","a")
		log(log_file, "NexusServer starting...")
		
		begin
			config = ParseConfig.new "./nexus.conf"
			db_flie = "/tmp/nexus_modules.db"
			File.delete(db_flie) if File.exist?(db_flie)
			db = SQLite3::Database.new db_flie
			db.execute "CREATE TABLE Modules(uuid TEXT, name TEXT, class TEXT, room TEXT, hardware TEXT, UNIQUE(uuid));"
		rescue => e
			log(log_file, "Unable to start NexusServer: #{e}", true)
		end
		
		config.params.each do |k, v|
			if v.class == Hash
				uuid = k
				name = v['name']
				type = v['type']
				room = v['room']
				hardware = v['hardware']
				db.execute "INSERT INTO Modules VALUES(?,?,?,?,?);", [uuid, name, type, room, hardware]
				log(log_file, "Parsed module #{uuid}: name => #{name}, room => #{room}, type => #{type}, hardware => #{hardware}")
				module_class = Module.const_get(type)
				module_class.send_events(settings.controller, uuid) if module_class.methods.include? :send_events
			else
				set k.to_sym, v
			end
		end
		
		begin
			report_modules(db, settings.controller)
		rescue => e
			log(log_file, "Error: could not report modules to controller: #{e}")
		end
		
		set :db, db
		set :log_file, log_file
	
	end

	get '/modules' do
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
		row = settings.db.execute "SELECT class,hardware FROM Modules WHERE uuid=?;", [uuid]
		if row.size == 0
			Nexus.log(settings.log_file, "Error: requested uuid #{uuid} was not found in the database")
			status 404
			return 
		end
		
		mod = row[0]
		begin
			type = Module.const_get(mod[0])
		rescue NameError => e
			Nexus.log(settings.log_file, "Error: hardware configured with class name #{mod[0]} but no class found")
			status 501
			return
		end
		
		hardware = mod[1]
		begin
			body type.query_state(hardware)
		rescue
			Nexus.log(settings.log_file, "Error: hardware query error: #{e}")
			status 501
			return
		end
		
		status 200
	end
	
	get '/set/:uuid/:state' do |uuid, state|
		row = settings.db.execute "SELECT class,hardware FROM Modules WHERE uuid=?;", [uuid]
		if row.size == 0
			Nexus.log(settings.log_file, "Error: requested uuid #{uuid} was not found in the database")
			status 404
			return 
		end
		
		mod = row[0]
		begin
			type = Module.const_get(mod[0])
		rescue NameError => e
			Nexus.log(settings.log_file, "Error: hardware configured with class name #{mod[0]} but no class found")
			status 501
			return
		end
		
		if !type.methods.include? :set_state
			Nexus.log(settings.log_file, "Error: module class #{mod[0]} does not implement setting a state")
			status 501
			return 
		end
		
		hardware = mod[1]
		begin
			body type.set_state(hardware, state)
		rescue => e
			Nexus.log(settings.log_file, "Error: hardware set error: #{e}")
		end
		
		Nexus.log(settings.log_file, "Set #{uuid} to #{state}")
		status 200
	end
	
end

#webserver = Thread.new{ Nexus.run! }
#Thread.new( PiPiper.wait )
#webserver.join
