float g_dt = 0;
float HALF_PI = 1.57079632679;
string surface_override = "";
string active_map_uuid;
string active_map_totd_date;
bool is_totd;
ScatterHistogram scatterHistogram;
CotdApi @cotdApi;
Debouncer debounce = Debouncer();
float pbTime;
uint64 lastFrameTime = Time::Now;
bool focused;

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

bool shouldNotRender() {
    bool ret = !g_visible
      || !UI::IsRendering()
      || getMapUid() == ""
      || (!SHOW_WITH_HIDDEN_INTERFACE && !UI::IsGameUIVisible()) 
      || GetApp().CurrentPlayground is null
      || GetApp().CurrentPlayground.Interface is null;
      
    return ret;
}

void RenderInterface() {
  if (RENDERINTERFACE_RENDER_MODE) {
    DoRender();
  }
}

void Render() {
  if (!RENDERINTERFACE_RENDER_MODE) {
    DoRender();
  }
}


void DoRender() {
  if (shouldNotRender()) {
    return;
  }
  lastFrameTime = Time::Now;
  auto app = GetApp();
  if (app.CurrentPlayground!is null && (app.CurrentPlayground.UIConfigs.Length > 0)) {
    if (app.CurrentPlayground.UIConfigs[0].UISequence == CGamePlaygroundUIConfig::EUISequence::Intro) {
      return;
    }
  } if (getMapUid() == "") {
    return;
  }
  scatterHistogram.render();
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
}

Json::Value@ getTimeMatchedChallenges(Json::Value@ val, uint64 time) {
  Json::Value@ out_val = Json::Array();
  for (uint i = 0; i < val.Length; i++) {
    int sd = val[i]["startDate"];

    if (Math::Abs(time - sd) <= (60 * 60 * 2) ) {
      out_val.Add(val[i]);
    }
  }
  return out_val;
}

int GetChallengeForDate(string date) {
  // Crossplay start - 5/15/2023
  // 3 COTD start - Aug 11 2021

  // Also - keep in mind the max offset possible. 

  // 5 platforms per COTD
  // 3 COTD per day
  // Start at the day in front of the target date, then work backwards

  uint64 expectedStartTime = ParseTime(date) + (17 * 60 + 1) * 60;

  uint64 consoleStartTime = ParseTime("2023-05-15") + (17 * 60 + 1) * 60;
  uint64 threeCOTDStartTime = ParseTime("2021-08-11")+ (17 * 60 + 1) * 60;
  uint64 currentTime = ParseTime(Time::FormatString("20%y-%m-%d", Time::get_Stamp())) + (17 * 60 + 1) * 60;

  int previousDateChallenge = _GetChallengeForDate(100, 0, currentTime - (60 * 60 * 24), 0);

  if (previousDateChallenge == -1) {
    print("Couldn't resolve a proper previousDateChallenge! Using hardcoded value from 8/19/23 instead: ");
    previousDateChallenge = 4469;
  }

  print("Previous date's challenge: " + tostring(previousDateChallenge));

  int challengeGuessOffset = 0;
  challengeGuessOffset += getExpectedChallenges(
    Math::Max(consoleStartTime, expectedStartTime), currentTime, 15
  );

  if (expectedStartTime < consoleStartTime) {
    challengeGuessOffset += getExpectedChallenges(
      Math::Max(threeCOTDStartTime, expectedStartTime), consoleStartTime, 3
    );

  }

  if (expectedStartTime < threeCOTDStartTime) {
    challengeGuessOffset += getExpectedChallenges(
      expectedStartTime, consoleStartTime, 1
    );
  }
  
  challengeGuessOffset = Math::Min(challengeGuessOffset, previousDateChallenge);

  return _GetChallengeForDate(100, challengeGuessOffset, expectedStartTime, 0);
}

int getExpectedChallenges(uint64 start, uint64 end, int numPerDay) {
  return (numPerDay) * ((end - start) / (60 * 60 * 24));
}

/* recursive internal method to handle trekking forwards/backwards */ 
int _GetChallengeForDate (int length, int offset, uint64 expectedStartTime, int count) {
  trace("_GetChallengeForDate: " + tostring(length) + "\t" + tostring(offset) + "\t" + tostring(expectedStartTime) + "\t" + tostring(count));
  if (count == 100) {
    warn("Failed to find a matching challenge!");
    return -1;
  }

  Json::Value@ challenges = CotdApi().GetChallenges(length, offset);
  Json::Value@ timeMatchedChallenges = getTimeMatchedChallenges(challenges, expectedStartTime);

  if (challenges.Length == 0 && count != 0) {
    warn("No challenges found for this date! Returning 0.");
    return -1;
  }

  if (challenges.Length == 0 && count == 0) {
    print("No challenges found! We probably jumped too far forwards - going backwards.");
    return _GetChallengeForDate(length, offset - length, expectedStartTime, count);

  }
  if (timeMatchedChallenges.Length == 0) {

    uint64 maxTime, minTime;

    for (uint i = 0; i < challenges.Length; i++) {
      if (string(challenges[i]["name"]).Contains("Cup of the Day") || string(challenges[i]["name"]).Contains("COTD")) {
        maxTime = challenges[i]["startDate"];
        break;
      }
    }
    for (uint i = challenges.Length - 1; i >= 0; i--) {
      if (string(challenges[i]["name"]).Contains("Cup of the Day") || string(challenges[i]["name"]).Contains("COTD")) {
        minTime = challenges[i]["startDate"];
        break;
      }
    }

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
    return -1; 
  }

  for (uint i = 0; i < timeMatchedChallenges.Length; i++) {
    string name = timeMatchedChallenges[i]["name"];
    if (name.Contains("#1 - Challenge") || (name.Contains(" - Challenge") && !name.Contains("#"))) {
      print(name);
      return timeMatchedChallenges[i]["id"];
    }
  }
  return -1;
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

void OnMouseWheel(int _, int y) {
  scatterHistogram.OnMouseWheel(y);
}

void YieldByTime() {
  if (Time::get_Now() - lastFrameTime > MAX_FRAMETIME) {
    yield();
  }
}