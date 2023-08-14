float g_dt = 0;
float HALF_PI = 1.57079632679;
string surface_override = "";
string active_map_uuid;
string active_map_totd_date;
bool is_totd;
vec2 m_size;
ScatterHistogram scatterHistogram;
CotdApi @cotdApi;
Debouncer debounce = Debouncer();
float pbTime;

SQLite::Database@ db = SQLite::Database(":memory:");

string getMapUid() {
  auto app = cast < CTrackMania > (GetApp());
  if (@app != null) {
    if (@app.RootMap != null) {
      if (@app.RootMap.MapInfo != null) {
        return app.RootMap.MapInfo.MapUid;
      }
    }
  }
  return "";
}

void RenderMenu() {
  if (UI::BeginMenu(Icons::Cog + " PB Grapher")) {
    if (UI::MenuItem("Manage Custom Time Targets")) {
      showTimeInputWindow = !showTimeInputWindow;
    }
      if (UI::MenuItem("Switch to/from Histogram")) {
      HISTOGRAM_VIEW = !HISTOGRAM_VIEW;
    }
      if (UI::MenuItem("Show/Hide Graph")) {
      g_visible = !g_visible;
    }
    UI::EndMenu();
  }
}

bool shouldNotRender() {
    bool ret = !g_visible
      || !UI::IsRendering()
      || getMapUid() == ""
      || (!SHOW_WITH_HIDDEN_INTERFACE && !UI::IsGameUIVisible())
      || GetApp().CurrentPlayground is null
      || GetApp().CurrentPlayground.Interface is null;
    return ret;
}

void Render() {
  auto app = GetApp();
  if (app.CurrentPlayground!is null && (app.CurrentPlayground.UIConfigs.Length > 0)) {
    if (app.CurrentPlayground.UIConfigs[0].UISequence == CGamePlaygroundUIConfig::EUISequence::Intro) {
      return;
    }
  } if (getMapUid() == "") {
    return;
  }
  scatterHistogram.render();
  m_size = vec2(graph_width, graph_height);
  
}

void Main() {
  NadeoServices::AddAudience("NadeoClubServices");
  NadeoServices::AddAudience("NadeoLiveServices");

  while (!NadeoServices::IsAuthenticated("NadeoClubServices")) {
    yield();
  }

  while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) {
    yield();
  }
      
  TOTD::LoadTOTDs();

  // print(GetDateForChallenge(0));
  // print(GetDateForChallenge(1));
  // print(GetDateForChallenge(2));
}

bool isMainQualifier(string testVal) {
  return testVal.Contains("#1 - Challenge");
}

Json::Value@ getTimeMatchedChallenges(Json::Value@ val, uint64 time) {
  Json::Value@ out_val = Json::Array();
  for (int i = 0; i < val.Length; i++) {
    int sd = val[i]["startDate"];

    if (Math::Abs(time - sd) <= (60 * 60 * 2) ) {
      out_val.Add(val[i]);
    }
  }
  return out_val;
}

array<string> getChallengeNames(Json::Value@ val) {
  array<string> o; 
  for (int i = 0; i < val.Length; i++) {
    o.InsertLast(val[i]["name"]);
  }
  return o; 
}

int GetChallengeForDate(string date) {
  // 5 platforms per COTD
  // 3 COTD per day
  // Start at the day in front of the target date, then work backwards

  uint64 expectedStartTime = ParseTime(date) + (17 * 60 + 1) * 60;
  uint64 currentTime = ParseTime(Time::FormatString("20%y-%m-%d", Time::get_Stamp())) + (17 * 60 + 1) * 60;

  uint64 diff = currentTime - expectedStartTime;
  int dayDiff = diff / (60 * 60 * 24);

  trace("Day diff: " + tostring(dayDiff));
  int offset = 0;
  if (dayDiff == 0) {
    offset = 0;
  } else {
    offset = 15 * (dayDiff - 1);
  }

  return _GetChallengeForDate(100, offset, expectedStartTime, 0);
}

/* recursive internal method to handle trekking forwards/backwards */ 
int _GetChallengeForDate (int length, int offset, uint64 expectedStartTime, int count) {
  trace("_GetChallengeForDate: " + tostring(length) + "\t" + tostring(offset) + "\t" + tostring(expectedStartTime) + "\t" + tostring(count));
  if (count == 100) {
    warn("Failed to find a matching challenge!");
    return 0;
  }

  Json::Value@ challenges = CotdApi().GetChallenges(length, offset);
  Json::Value@ timeMatchedChallenges = getTimeMatchedChallenges(challenges, expectedStartTime);

  if (challenges.Length == 0) {
    warn("No challenges found for this date! Returning 0.");
    return 0;
  }
  if (timeMatchedChallenges.Length == 0) {
    int maxTime = challenges[0]["startDate"];
    int minTime = challenges[challenges.Length - 1]["startDate"];

    if (expectedStartTime < maxTime && expectedStartTime > minTime) {
      warn("No COTD found within time window!");
      return 0;
    } else {
      if (expectedStartTime > maxTime) {
        return _GetChallengeForDate(length, offset - length, expectedStartTime, count + 1);
      } else {
        return _GetChallengeForDate(length, offset + length, expectedStartTime, count + 1);
      }
    }
    return 0; 
  }

  for (int i = 0; i < timeMatchedChallenges.Length; i++) {
    string name = timeMatchedChallenges[i]["name"];
    if (name.Contains("#1 - Challenge")) {
      return timeMatchedChallenges[i]["id"];
    }
  }
  return 0;
}


string GetDateForChallenge(int offset) {
  // 5 platforms per COTD
  // 3 COTD per day
  // We're looking for the one with the substring "COTD YYYY-MM-DD #1 - Challenge"

  Json::Value@ val = CotdApi().GetChallenges(20, offset);

  IO::File new_file("C:/Users/jjsch/repos/competition-graphs/challengeOutput.json");
  new_file.Open(IO::FileMode::Write);
  new_file.Write(Json::Write(val));
  new_file.Close();

  string name = val[0]["name"];
  return name.SubStr(5, 18);

}


void OnMouseButton(bool down, int button, int x, int y) {
  scatterHistogram.OnMouseButton(down, button, x, y);
}

void OnSettingsChanged() {
  scatterHistogram.OnSettingsChanged();
}

/* copied from XertroV::cotd_hud */ 
CTrackMania@ GetTmApp() {
    return cast<CTrackMania>(GetApp());
}
/* end copied */ 

uint64 ParseTime(const string &in inTime) {
  auto st = db.Prepare("SELECT unixepoch(?) as x");
  st.Bind(1,  inTime);
  st.Execute();
  st.NextRow();
  st.NextRow();
  return st.GetColumnInt64("x");
}