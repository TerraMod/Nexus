class LightSensor
	def self.query_state(hardware)
		# hardware is a string defining the hardware defined in the configuation file
		# return the sensor data that corresponds to the hardware module
	end

	def self.set_state(hardware, state)
		# hardware is a string defining the hardware defined in the configuation file
		# state is captured in the url and desribes where the hardware should be
		# attempt to make the change, then return any relevent information
	end

	def self.send_events(controller, uuid)
		# pi_piper hookups to watch the pin
		# sent the uuid to the controller when theres an event
		# this has to be non-blocking, so if PiPiper.wait is required, it will be called at the bottom of nexus.rb
	end
end
