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
    array<DataPoint> json_payload;
    float created_ts;
    float updated_ts;
    float last_update_started_ts;
    int refresh_in;
    Challenge challenge;
    bool updated;

    array<Div> divs(128);

    ChallengeData() {}

    ChallengeData(int challenge_id, const string &in uid, int length, int offset, const array<DataPoint> &in json_payload, float created_ts, float updated_ts, float last_update_started_ts, int refresh_in, const Challenge &in challenge) {
        this.challenge_id = challenge_id;
        this.uid = uid;
        this.length = length;
        this.offset = offset;
        this.json_payload = json_payload;
        this.created_ts = created_ts;
        this.updated_ts = updated_ts;
        this.last_update_started_ts = last_update_started_ts;
        this.refresh_in = refresh_in;
        this.challenge = challenge;
    }

    ChallengeData(string _map_uuid) {
        this.uid = _map_uuid;
        startnew(CoroutineFunc(this.load));
    }

    void changeMap(string _map_uuid) {
        this.uid = _map_uuid;
        this.json_payload.RemoveRange(0, json_payload.Length);
        startnew(CoroutineFunc(this.load));
    }

    void load() {
        print("Loading offset " + tostring(offset) + " with length " + tostring(length));

        print("https://map-monitor.xk.io/api/challenges/4347/records/maps/" + this.uid + "?length=" + tostring(this.length) + "&offset=" + tostring(this.offset));
        Net::HttpRequest@ request = Net::HttpGet("https://map-monitor.xk.io/api/challenges/4347/records/maps/" + this.uid + "?length=" + tostring(this.length) + "&offset=" + tostring(this.offset));
        int points_added;
        while (!request.Finished()) {
            yield();
        }
        if (request.ResponseCode() == 200) {
            Json::Value@ obj = Json::Parse(request.String());
            print(request.String());
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
            if (points_added == this.length) {
                this.offset += this.length;
                load();
                print("Loading additional data");
            }   
            processDivs();

        } else {
            is_totd = false;
        }
    }

    int parseDataPoint(Json::Value@ obj) {
        for (int i = 0; i < obj.Length; i++) {
            json_payload.InsertLast(DataPoint(obj[i]));
            print("Now at item " + tostring(json_payload.Length));
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
        this.divs.InsertLast(this.divs[active_div_number]);

        
    }
}

class DataPoint
{
	int time;
    string player;
    int rank;
    int div;
	
	DataPoint() {}

    DataPoint(Json::Value@ obj) {
        this.time = obj["time"];
        this.player = obj["player"];
        this.rank = obj["rank"];
        this.div = 1 + (rank / 64);
    }
    
}

class Div
{
    int min_time;
    int max_time; 
    Div() {}
    
    Div(int min_time, int max_time) {
        this.min_time = min_time;
        this.max_time = max_time;
    }

    string tostring() {
        return 
            "min\t" + Text::Format("%d", this.min_time) + "\tmax\t" + Text::Format("%d", this.max_time);
    }
    
}