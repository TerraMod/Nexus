#!/usr/bin/env ruby

require 'sinatra/base'
require 'parseconfig'
require 'sqlite3'
require 'sequel'
require 'json'
require 'securerandom'
require 'rest-client'
require 'thread'
require 'pi_piper'
Dir["./modules/*.rb"].each { |file| require file }
include PiPiper

class Nexus < Sinatra::Base

	def self.report_event()
		event = {
			:type => "EventReport"
		}
		# post this
	end
	
	def self.report_modules
	
	end
		
	helpers do

		#prevent connections that come from anywhere but terramod


	end

	configure do

		# Parse configuration file, create database
		config = ParseConfig.new "./nexus.conf"
		db_flie = "nexus_modules.db"
		File.delete(db_flie) if File.exist?("./#{db_flie}")
		set :orm, Sequel.connect("sqlite://#{db_file}")
		settings.orm.create_table :modules
			String :uuid, :unique => true
			String :class
			String :name
			String :room
		end

		# Populate database and send NexusReport
		modules = {}
		config.params.each do |k, v|
			if v.class == Hash
				modules[k] = v
				uuid = k
				name = v['name']
				type = v['type']
				room = v['room']
				hardware = v['hardware']
				settings.orm[:modules].insert(
					:uuid => uuid,
					:class => type,
					:name => name,
					:room => room
				)
				module_class = Module.const_get(type)
				module_class.setup(settings.orm, uuid, hardware)
			else
				set k.to_sym, v
			end
		end
		report_modules#event {"type" => "NexusReport", "uuid" => settings.uuid, "data" => modules}

		# Provide reference to report_event
		set :report_event, self.method(:report_event)

	end

	get '/modules' do

		modules = {}
		settings.orm[:modules].each do |mod|
			modules[mod[:uuid]] = {
				"class" => mod[:class],
				"name" => mod[:name],
				"room" => mod[:room]
			}
		end
		return modules.to_json

	end

	post '/rename' do
		# uuid
		# name
		# room
	end

	get '/functions/:module_uuid' do |module_uuid|
		# return the public class methods of that module's type except .setup
	end

	post '/call'
		# uuid
		# function
		# arguments
	end

end
