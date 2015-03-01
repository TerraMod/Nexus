class MotionSensor

	def self.watch_hardware(uuid, hardware, event_queue, db)
		watch :pin => hardware do
			event_queue << {"type" => "EventReport", "uuid" => uuid, "data" => "motion"}
		end
	end
	
	def self.clear_state(hardware)
		system "echo #{hardware} > /sys/class/gpio/unexport"
	end
end
