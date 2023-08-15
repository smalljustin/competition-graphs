class Challenge {
    int challenge_id;
    string uid;
    string name;
    int leaderboard_id;
    int start_ts;
    int end_ts;
    int created_ts;
    int updated_ts;

    Challenge() {}

    Challenge(int challenge_id, const string &in uid, const string &in name, int leaderboard_id, int start_ts, int end_ts, int created_ts, int updated_ts) {
        this.challenge_id = challenge_id;
        this.uid = uid;
        this.name = name;
        this.leaderboard_id = leaderboard_id;
        this.start_ts = start_ts;
        this.end_ts = end_ts;
        this.created_ts = created_ts;
        this.updated_ts = updated_ts;
    }

    Challenge(Json::Value@ obj) {
        this.challenge_id = obj["challenge_id"];
        this.uid = obj["uid"];
        this.name = obj["name"];
        this.leaderboard_id = obj["leaderboard_id"];
        this.start_ts = obj["start_ts"];
        this.end_ts = obj["end_ts"];
        this.created_ts = obj["created_ts"];
        this.updated_ts = obj["updated_ts"];
    }
}

class ChallengeData {
    int challenge_id;
    string uid;
    int length = 100;   
    int offset;
    array<DataPoint@>@ json_payload = array<DataPoint@>();
    float created_ts;
    float updated_ts;
    float last_update_started_ts;
    int refresh_in;
    Challenge challenge;
    bool updated;


    bool locked = false;

    array<Div> divs(128);

    ChallengeData() {}

    ChallengeData(string _map_uuid) {
        this.uid = _map_uuid;
        startnew(CoroutineFunc(this.load));
    }

    void changeMap(int challenge_id, string _map_uuid) {
        this.uid = _map_uuid;
        this.challenge_id = challenge_id;
        this.json_payload.RemoveRange(0, this.json_payload.Length);
        this.offset = 0;
        startnew(CoroutineFunc(this.load));
    }

    void load_external() {
        if (locked) {
            return;
        }
        trace("External call: doing load.");
        locked = true;
        this.load();
    }

    void load() {
        if (offset >= MAX_RECORDS) {
            processDivs();
            locked = false;
            return;
        }
        print("Loading offset " + tostring(offset) + " with length " + tostring(length));
        print("https://map-monitor.xk.io/api/challenges/" + this.challenge_id + "/records/maps/" + this.uid + "?length=" + tostring(this.length) + "&offset=" + tostring(this.offset));
        Net::HttpRequest@ request = Net::HttpGet("https://map-monitor.xk.io/api/challenges/"+ this.challenge_id + "/records/maps/" + this.uid + "?length=" + tostring(this.length) + "&offset=" + tostring(this.offset));
        int points_added;
        while (!request.Finished()) {
            yield();
        }
        if (request.ResponseCode() == 200) {
            Json::Value@ obj = Json::Parse(request.String());
            this.challenge_id = obj["challenge_id"];
            this.uid = obj["uid"];
            this.length = obj["length"];
            this.offset = obj["offset"];
            points_added = parseDataPoint(obj["json_payload"]);
            this.created_ts = obj["created_ts"];
            this.updated_ts = obj["updated_ts"];
            this.last_update_started_ts = obj["last_update_started_ts"];
            this.refresh_in = obj["refresh_in"];
            this.challenge = Challenge(obj["challenge"]);
            this.updated = true;
            this.offset += obj["json_payload"].Length;
            if (points_added == this.length) {
                load();
            } else {
                locked = false;
            }
            processDivs();
        } else {
            is_totd = false;
        }
    }

    int parseDataPoint(Json::Value@ obj) {
        for (int i = 0; i < obj.Length; i++) {
            json_payload.InsertLast(DataPoint(obj[i]));
        }
        return obj.Length;
    }


    void processDivs() {
        int active_div_number = 0;
        for (int i = 0; i < this.json_payload.Length; i++) {
            DataPoint@ dp = this.json_payload[i];
            if (dp.div != active_div_number) {
                active_div_number = dp.div;
                this.divs[active_div_number].min_time = dp.time;
                this.divs[active_div_number].max_time = dp.time;
            }
            this.divs[active_div_number].max_time = dp.time;
        }
    }
}

class DataPoint
{
	int time;
    string player;
    int rank;
    int div;
    float focus;
    bool visible;
    bool clicked;
	
	DataPoint() {}

    DataPoint(Json::Value@ obj) {
        this.time = obj["time"];
        this.player = obj["player"];
        this.rank = obj["rank"];
        this.div = 1 + (rank / 64);
        this.focus = 0;
        this.clicked = false;
    }

    bool decrease() {
        if (this.focus == 0) {
            return false;
        } else {
            this.focus = Math::Max(0, this.focus - 0.1);
        }
        this.visible = false;
        return true;
    }
    void increase() {
        this.focus = Math::Min(1, this.focus + 0.5);
    }    
}

class Div
{
    int min_time;
    int max_time;
    float render_fade;
    Div() {
        min_time = 0;
        max_time = 10 ** 6;
    }
    
    Div(int min_time, int max_time) {
        this.min_time = min_time;
        this.max_time = max_time;
        this.render_fade = 0;
    }

    void increase() {
        this.render_fade = Math::Min(render_fade + 0.05, 1);
    }

    void decrease() {
        this.render_fade = Math::Max(render_fade - 0.01, 0);
    }

    string tostring() {
        return 
            "min\t" + Text::Format("%d", this.min_time) + "\tmax\t" + Text::Format("%d", this.max_time);
    }
    
}