class CpLog
{
	int cp_log_id;
	string map_uuid;
	string player_uuid;
	int run_id;
	float time;
	
	CpLog() {}

	CpLog(string _map_uuid, string _player_uuid, int _run_id, float _time) {
		map_uuid = _map_uuid;
		player_uuid = _player_uuid;
		run_id = _run_id;
		time = _time;

		if (time < 0) {
			log("Warning: Provided time is below zero. Taking the absolute value.");
			time = Math::Abs(time);
		}
	}

	CpLog(SQLite::Statement@ statement) {
		cp_log_id = statement.GetColumnInt("cp_log_id");
		map_uuid = statement.GetColumnString("map_uuid");
		player_uuid = statement.GetColumnString("player_uuid");
		run_id = statement.GetColumnInt("run_id");
		time = statement.GetColumnInt("time");
	}

	void saveToStatement(SQLite::Statement@ statement) {
		statement.Bind(1, map_uuid);
		statement.Bind(2, player_uuid);
		statement.Bind(3, run_id);
		statement.Bind(4, time);
	}

	string tostring() {
		return "{\"cp_log_id\": " + cp_log_id + ", \"map_uuid\": \"" + map_uuid 
		+ "\"\", \"run_id\": " + run_id + ", \"player_uuid\": " + player_uuid
		+ ", \"time\": " + time + "}";
	}
}