class EntranceSensor
	def self.set_state(hardware, state)
		return "Success setting #{state}\n"
	end
	
	def self.query_state(hardware)
		return "open\n"
	end
	
	def self.send_events(controller, uuid)
		
	end
end
