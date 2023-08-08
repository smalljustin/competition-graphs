class DatabaseFunctions {
    string database_filename = "pb_grapher_store.db";
    SQLite::Database@ database;

    array<array<CpLog>> pendingCpLogArrayBuffer;

    string getCpLogsForMapSql = """
        SELECT cl.cp_log_id, cl.map_uuid, cl.run_id, cl.cp_id, cl.time FROM cp_log cl 
        JOIN run_time rt 
        ON cl.map_uuid = rt.map_uuid AND cl.run_id = rt.run_id
        WHERE cl.map_uuid = ?
        ORDER BY cl.run_id, cl.cp_id
    """;
    DatabaseFunctions() {
        string proper_path = IO::FromStorageFolder(database_filename);
        SQLite::Database@ db = SQLite::Database(proper_path);
        @database = db;
        database.Execute("CREATE TABLE IF NOT EXISTS cp_log (cp_log_id INTEGER PRIMARY KEY AUTOINCREMENT, map_uuid VARCHAR, player_id VARCHAR, time FLOAT, UNIQUE(map_uuid, run_id, cp_id))");
        database.Execute("CREATE TABLE IF NOT EXISTS custom_time_targets (custom_target_id INTEGER PRIMARY KEY AUTOINCREMENT, map_uuid VARCHAR, target_time FLOAT)");
        // https://phiresky.github.io/blog/2020/sqlite-performance-tuning/
        database.Execute("pragma journal_mode = WAL;");
        database.Execute("pragma synchronous = normal;");
    }

    void persist() {
        for (int i = 0; i < pendingCpLogArrayBuffer.Length; i++) {
            _persistBuffer(pendingCpLogArrayBuffer[i]);
        }
    }

    void persistBuffer(array<CpLog> active_run_buffer) {
        pendingCpLogArrayBuffer.InsertLast(active_run_buffer);
        startnew(CoroutineFunc(this.persist));
    }


    void _persistBuffer(array<CpLog> active_run_buffer) {
        string sql = "INSERT INTO cp_log (map_uuid, run_id, cp_id, time) VALUES (?, ?, ?, ?)";
        for (int i = 0; i < active_run_buffer.Length; i++) {
            SQLite::Statement@ stmt = database.Prepare(sql);
            active_run_buffer[i].saveToStatement(stmt);
            stmt.Execute();
        }
    }

    int getMaxPreviousRunId(string _map_uuid) {
        SQLite::Statement@ num_runs_stmt = database.Prepare("SELECT max(run_id) max_id FROM cp_log WHERE map_uuid = ? AND cp_id = 0 GROUP BY map_uuid");
        num_runs_stmt.Bind(1, _map_uuid);
        num_runs_stmt.Execute();
        num_runs_stmt.NextRow();
        if (!num_runs_stmt.NextRow()) {
            return 0;
        };
        return num_runs_stmt.GetColumnInt("max_id");
    }

    int getNumRunsForMap(string _map_uuid) {
        SQLite::Statement@ num_runs_stmt = database.Prepare("SELECT count(run_id) num_runs FROM cp_log WHERE map_uuid = ? AND cp_id = 0 GROUP BY map_uuid");
        num_runs_stmt.Bind(1, _map_uuid);
        num_runs_stmt.Execute();
        num_runs_stmt.NextRow();
        if (!num_runs_stmt.NextRow()) {
            return 0;
        };
        return num_runs_stmt.GetColumnInt("num_runs");
    }

    void resetMapData(string _map_uuid) {
        if (_map_uuid != "") {
            SQLite::Statement@ clear_map_data_stmt = database.Prepare("DELETE FROM cp_log WHERE map_uuid = ?");
            clear_map_data_stmt.Bind(1, _map_uuid);
            clear_map_data_stmt.Execute();
        }
    }

    array<array<CpLog>> getCpLogsForMap(string _map_uuid) {
        int num_runs = getNumRunsForMap(_map_uuid);

        array<array<CpLog>> cpLogsForMap(num_runs, array<CpLog>());

        if (num_runs == 0) {
            return cpLogsForMap;
        }

        int current_run = -1;
        int idx = -1;

        SQLite::Statement@ statement = database.Prepare(getCpLogsForMapSql);
        statement.Bind(1, _map_uuid);
        // statement.Execute(); not needed; query auto-runs.
        while (statement.NextRow()) {
            CpLog cp_log_tmp = CpLog(statement);
            if (cp_log_tmp.run_id != current_run) {
                idx += 1;
                current_run = cp_log_tmp.run_id;
            }
            cpLogsForMap[idx].InsertLast(cp_log_tmp);
        }
        log("Returning " + cpLogsForMap.Length + " runs.");
        return cpLogsForMap;
    }

    void addCustomTimeTarget(string _map_uuid, float target_time) {
        if (_map_uuid == "") {
            return;
        }
        target_time *= 1000;
        string addCustomTimeTargetSql = "INSERT INTO custom_time_targets (map_uuid, target_time) VALUES (?, ?)";
        SQLite::Statement@ statement = database.Prepare(addCustomTimeTargetSql);
        statement.Bind(1, _map_uuid);
        statement.Bind(2, target_time);
        log(statement.GetQueryExpanded());
        statement.Execute();
    }

    void removeAllCustomTimeTargets(string _map_uuid) {
        string deleteCustomTimeTargetSql = "DELETE FROM custom_time_targets WHERE map_uuid = ?";
        SQLite::Statement@ statement = database.Prepare(deleteCustomTimeTargetSql);
        statement.Bind(1, _map_uuid);
        statement.Execute();
    }

    array<CustomTimeTarget> getCustomTimeTargetsForMap(string _map_uuid) {
        array<CustomTimeTarget> customTimeTargets();
        if (_map_uuid == "") {
            return customTimeTargets;
        }
        string getCustomTimeTargetsForMapSql = "SELECT custom_target_id, map_uuid, target_time FROM custom_time_targets WHERE map_uuid = ?";
        SQLite::Statement@ statement = database.Prepare(getCustomTimeTargetsForMapSql);
        statement.Bind(1, _map_uuid);
        while (statement.NextRow()) {
            CustomTimeTarget custom_target = CustomTimeTarget(statement);
            customTimeTargets.InsertLast(custom_target);
        }
        log("Returning " + customTimeTargets.Length + " custom time targets.");
        return customTimeTargets;
    }
}