GraphHud @ graphHud;
DatabaseFunctions @ databasefunctions;
float g_dt = 0;
float HALF_PI = 1.57079632679;
string surface_override = "";

vec2 m_size = vec2(graph_width, graph_height);

void Update(float dt) {
  graphHud.update();
}

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
      graphHud.OnSettingsChanged();
    }
      if (UI::MenuItem("Show/Hide Graph")) {
      g_visible = !g_visible;
      graphHud.OnSettingsChanged();
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
  if (RENDERINTERFACE_RENDER_MODE || shouldNotRender()) {
    return;
  }
  if (graphHud!is null) {
    auto app = GetApp();
    if (app.CurrentPlayground!is null && (app.CurrentPlayground.UIConfigs.Length > 0)) {
      if (app.CurrentPlayground.UIConfigs[0].UISequence == CGamePlaygroundUIConfig::EUISequence::Intro) {
        return;
      }
    }
      graphHud.Render();
  }
}

void RenderInterface() {
  if (!RENDERINTERFACE_RENDER_MODE || shouldNotRender()) {
    return;
  }
  if (graphHud!is null) {
    auto app = GetApp();
    if (app.CurrentPlayground!is null && (app.CurrentPlayground.UIConfigs.Length > 0)) {
      if (app.CurrentPlayground.UIConfigs[0].UISequence == CGamePlaygroundUIConfig::EUISequence::Intro) {
        return;
      }
    }
      graphHud.Render();
  }
}

void OnSettingsChanged() {
  graphHud.OnSettingsChanged();
}

void Main() {
  @graphHud = GraphHud();
  @databasefunctions = DatabaseFunctions();
  graphHud.OnSettingsChanged();
}

void OnMouseButton(bool down, int button, int x, int y) {
  graphHud.OnMouseButton(down, button, x, y);
}