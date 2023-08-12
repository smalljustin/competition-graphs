float g_dt = 0;
float HALF_PI = 1.57079632679;
string surface_override = "";
string active_map_uuid;
bool is_totd;
vec2 m_size;
ScatterHistogram scatterHistogram;

float pbTime;

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
}

void OnMouseButton(bool down, int button, int x, int y) {
  scatterHistogram.OnMouseButton(down, button, x, y);
}

void OnSettingsChanged() {
  scatterHistogram.OnSettingsChanged();
}
