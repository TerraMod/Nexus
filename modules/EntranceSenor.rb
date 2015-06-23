class EntranceSensor

	def self.setup(orm, uuid, hardware)

		# Clear this individual pin
		system "echo #{hardware} > /sys/class/gpio/unexport"

		# Create the entrance sensor table if needed
		if !orm.table_exists? :entrancesensors
			orm.create_table :entrancesensors do
				String :uuid
				String :state
				String :last_change
			end
		end

		# Watch this individual pin and save changes
		watch :pin => hardware do |pin|
			state = pin.read == 1 ? "closed" : "open"
			send_event(uuid, state)
			orm[:entrancesensors].replace(
				:uuid => uuid,
				:state => state,
				:last_change => Time.new.strftime("%Y-%m-%d %H:%M:%S")
			)
		end

	end
	
	def get_state(uuid)
		orm[:entrancesensors].where(:uuid => uuid).first[:state]
	end
	
	def last_activity
	
	end
end
