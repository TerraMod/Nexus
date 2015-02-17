class AudioOutput
	def self.query_state(hardware)
		# hardware is a string defining the hardware defined in the configuation file
		# return the sensor data that corresponds to the hardware module
	end

	def self.set_state(hardware, state)
		# hardware is a string defining the hardware defined in the configuation file
		# state is captured in the url and desribes where the hardware should be
		# attempt to make the change, then return any relevent information
	end
end
