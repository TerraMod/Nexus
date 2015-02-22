class EntranceSensor

	def self.watch_hardware(uuid, hardware, event_queue, db)
		watch :pin => hardware do
			value = pin.read
			event_queue << {"type" => "EventReport", "uuid" => uuid, "data" => value}
			db.execute "UPDATE Modules SET last_event = ? WHERE uuid=?;" [value, uuid]
		end
	end
	
	def self.clear_state(hardware)
		system "echo #{hardware} > /sys/class/gpio/unexport"
	end
end
