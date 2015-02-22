class LightSensor

	def self.watch_hardware(uuid, hardware, event_queue, db)
		Thread.new{
			loop {
				#get value from hardware
				#update db with new state
				#sleep 60
			}
		}
	end
end
