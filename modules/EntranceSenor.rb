class EntranceSensor

	def self.watch_hardware(uuid, hardware, event_queue, db)
		watch :pin => hardware do |pin|
			value = pin.read
			value = "closed" if value == 1
			value = "opened" if value == 0
			event_queue << {"type" => "EventReport", "uuid" => uuid, "data" => value}
			db.execute "UPDATE Modules SET last_state=? WHERE uuid=?;", [value, uuid]
		end
	end
	
	def self.clear_state(hardware)
		system "echo #{hardware} > /sys/class/gpio/unexport"
	end
end
