#!/usr/bin/env ruby

require 'sinatra/base'
require 'parseconfig'
require 'sqlite3'
require 'json'
#require 'pi_piper'
#include PiPiper

Dir["./modules/*.rb"].each {|file| require file }

class Nexus < Sinatra::Base

	def self.report_modules(db, controller, tls_cert)
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
		return modules.to_json	# post these to the controller
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
		
		set :db, db
	
		report_modules(db, settings.controller, settings.tls_cert)
		
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
		modules = {}
		row = settings.db.execute "SELECT class,hardware FROM Modules WHERE uuid=?;", [uuid]
		status 404; return if row.size == 0
		mod = row[0]
		type = Module.const_get(mod[0])
		hardware = mod[1]
		body type.query_state(hardware)
		status 200
	end
	
	get '/set/:uuid/:state' do |uuid, state|
		row = settings.db.execute "SELECT class,hardware FROM Modules WHERE uuid=?;", [uuid]
		status 404; return if row.size == 0
		mod = row[0]
		type = Module.const_get(mod[0])
		status 501; return if !type.methods.include? :set_state
		hardware = mod[1]
		body type.set_state(hardware, state)
		status 200
	end
	
end

webserver = Thread.new{ Nexus.run! }
#Thread.new( PiPiper.wait )
webserver.join
