class CustomTimeTarget
{
	int custom_target_id;
	string map_uuid;
	float target_time;

	CustomTimeTarget() {}

	CustomTimeTarget(string _map_uuid, float _target_time) {
		map_uuid = _map_uuid;
		target_time = _target_time;

		if (target_time < 0) {
			log("Warning: Provided target_time is below zero. Taking the absolute value.");
			target_time = Math::Abs(target_time);
		}
	}

	CustomTimeTarget(SQLite::Statement@ statement) {
		custom_target_id = statement.GetColumnInt("custom_target_id");
		map_uuid = statement.GetColumnString("map_uuid");
		target_time = statement.GetColumnFloat("target_time");
	}

	void saveToStatement(SQLite::Statement@ statement) {
		statement.Bind(1, map_uuid);
		statement.Bind(2, target_time);
	}

	string tostring() {
		return "{\"custom_target_id\": " + custom_target_id + ", \"map_uuid\": \"" + map_uuid 
		+ "\"\", \"target_time\": " + target_time + "}";
	}
}