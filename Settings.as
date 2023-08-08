[Setting category="General" name="Visible"]
bool g_visible = true;

[Setting category="General" name="Histogram View"]
bool HISTOGRAM_VIEW = false;

[Setting category="Scatter" name="Draw run distribution chart"]
bool DRAW_RIGHT_SIDE_SCATTER = false;

[Setting category="General" name="Save respawn runs"]
bool SAVE_RESPAWN_RUNS = false;

[Setting category="Display" name="Graph Width" drag min=50 max=2000]
int graph_width = 500;

[Setting category="Display" name="Graph Height" drag min=50 max=1000]
int graph_height = 150;

[Setting category="Display" name="Graph X Offset" drag min=0 max=4000]
int graph_x_offset = 32;

[Setting category="Display" name="Graph Y Offset" drag min=0 max=2000]
int graph_y_offset = 32;

[Setting category="Display" name="Line Width" drag min=0 max=5]
float LineWidth = 2.0f;

[Setting category="Display" name="Backdrop Color" color]
vec4 BackdropColor = vec4(0, 0, 0, 0.7f);

[Setting category="Display" name="Border Color" color]
vec4 BorderColor = vec4(0, 0, 0, 1);

[Setting category="Display" name="Border Width" drag min=0 max=10]
float BorderWidth = 1.0f;

[Setting category="Display" name="Border Radius" drag min=0 max=50]
float BorderRadius = 5.0f;

float Padding = .25f;

[Setting category="Scatter" name="Scatter view: Past runs to draw" drag min=2 max=5000]
int NUM_SCATTER_PAST_GHOSTS = 4000;

[Setting category="Display" name="Point radius" min=0.1 max=10 drag]
float POINT_RADIUS = 1.5;

[Setting category="Display" name="Point fade color" color]
vec4 POINT_FADE_COLOR = vec4(1, 1, 1, 1);

[Setting category="Display" name="PB Color" color]
vec4 PB_COLOR = vec4(0.5843137254901961, 0.9764705882352941, 0.8901960784313725, 1.0);

[Setting category="Scatter" name="Standard deviations to show below PB" drag min=0 max=2]
float LOWER_STDEV_MULT = 0.125;

[Setting category="Scatter" name="Standard deviations to show above PB" drag min=0 max=5]
float UPPER_STDEV_MULT = 2.5;

[Setting category="Display" name="Custom target color" color]
vec4 CUSTOM_TARGET_COLOR = vec4(0.5215686274509804, 0.4196078431372549, 0.6039215686274509, 1.0);

[Setting category="Display" name="Scatter point width (fraction of graph_width)" drag min=1 max=80]
float RIGHT_SCATTER_BAR_WIDTH = 20;

[Setting category="Display" name="Scatter point height (fraction of graph_height)" drag min=1 max=80]
float RIGHT_SCATTER_BAR_HEIGHT = 20;

[Setting category="Display" name="Right Side Scatter point opacity" drag min=0.01 max=1]
float RIGHT_SIDE_SCATTER_POINT_OPACITY = 0.1;

[Setting category="Display" name="Right Side Scatter border radius" drag min=0 max=10]
float RIGHT_SIDE_BORDER_RADIUS = 5; 

[Setting category="Medals" name="Draw Author Line"]
bool DRAW_AUTHOR = true;

[Setting category="Medals" name="Author Line Color" color]
vec4 AUTHOR_COLOR = vec4(0.003921568, 0.20784, 0.16078, 1);

[Setting category="Medals" name="Draw Gold Line"]
bool DRAW_GOLD = true;

[Setting category="Medals" name="Gold Line Color" color]
vec4 GOLD_COLOR = vec4(0.6823529411764706, 0.5529411764705882, 0.192156862745098, .7);

[Setting category="Medals" name="Draw Silver Line"]
bool DRAW_SILVER = true;

[Setting category="Medals" name="Silver Line Color" color]
vec4 SILVER_COLOR = vec4(.6509803921568627, .6509803921568627, .6509803921568627, .7);

[Setting category="Medals" name="Draw Bronze Line"]
bool DRAW_BRONZE = true;

[Setting category="Medals" name="Bronze Line Color" color]
vec4 BRONZE_COLOR = vec4(0.5490196078431373, 0.3529411764705882, 0.203921568627451, .7);

[Setting category="Scatter" name="Cutoff Multiplier for Slow Runs - Scatter" drag min=1 max=3]
float SLOW_RUN_CUTOFF_SCATTER = 1.15;

[Setting category="Scatter" name="Show over-time runs in graph"]
bool SHOW_OVERTIME_RUNS = true;

[Setting category="Display" name="Over-time run color" color]
vec4 OVERTIME_RUN_COLOR = vec4(0.19215686274509805, 0.6235294117647059, 0.5803921568627451, 1.0);

[Setting category="Display" name="Over-time run color fade constant" drag min=10 max=1000]
int OVERTIME_RUN_FADE_CONSTANT = 50;

[Setting category="Scatter" name="Max over-time run constant" drag min=1.1 max=10]
float OVERTIME_MAX_CONSTANT = 2;

[Setting category="Histogram" name="Histogram precision value" drag min=0.001 max=0.3]
float HIST_PRECISION_VALUE = 0.001;

[Setting category="Histogram" name="Histogram bottom margin" drag min=1 max=20]
int BOTTOM_MARGIN = 1;

[Setting category="Histogram" name="Past runs to show" drag min=25 max=5000]
int HIST_RUNS_TO_SHOW = 5000;

[Setting category="Histogram" name="Start offset (0 = current, 100 = '100 runs in past'" drag min=0 max=5000]
int HIST_RUN_START_OFFSET = 0;

[Setting category="Histogram" name="Cutoff Multiplier for Slow Runs - Histogram" drag min=1 max=1.5]
float SLOW_RUN_CUTOFF_HIST = 1.025;

[Setting category="Histogram" name="Always show run distribution text"]
bool HIST_ALWAYS_SHOW_RUN_INFO = false;

[Setting category="Histogram" name="Show target times in histogram"]
bool SHOW_MEDALS_IN_HISTOGRAM = true;

[Setting category="Scatter" name="Target fraction of runs to show" drag min=0.1 max=.8]
float SCATTER_TARGET_PERCENT = 0.875;

[Setting category="Scatter" name="Override: Show All Runs"]
bool SCATTER_SHOW_ALL_RUNS = false;

[Setting category="Scatter" name="Manually adjust scatter bounds"]
bool MANUAL_OVERRIDE_SCATTER_BOUNDS = false;

[Setting category="Display" name="Histogram run color" color]
vec4 HISTOGRAM_RUN_COLOR = vec4(0.19215686274509805, 0.6235294117647059, 0.5803921568627451, 1.0);

[Setting category="Display" name="Histogram best run color" color]
vec4 HISTOGRAM_PB_COLOR = vec4(0.5843137254901961, 0.9764705882352941, 0.8901960784313725, 1.0);

[Setting category="General" name="Show custom time input window"]
bool showTimeInputWindow = false;

[Setting category="General" name="Show graph when game interface hidden"]
bool SHOW_WITH_HIDDEN_INTERFACE = false;

[Setting category="General" name="Only render when Openplanet (F3) menu is open"] 
bool RENDERINTERFACE_RENDER_MODE = true;

[Setting category="General" name="Auto-adjust the scatter view bounds after each run"]
bool AUTO_ADJUST_VIEW_BOUNDS_POST_RUN = true;

[Setting category="General" name="Always include fastest custom target time in graph"]
bool INCLUDE_FASTEST_CUSTOM_TARGET_TIME = true;

[Setting category="General" name="Always include slowest custom target time in graph"]
bool INCLUDE_SLOWEST_CUSTOM_TARGET_TIME = true;

[Setting category="General" name="Override: Show by seconds above/below PB"]
bool OVERRIDE_SHOW_SECONDS = false;

[Setting category="General" name="Override: Seconds above PB (control-click to set value)" drag min=0 max=50]
float OVERRIDE_SECONDS_ABOVE_PB_SHOW = 3;

[Setting category="General" name="Override: Seconds below PB (control-click to set value)" drag min=0 max=50]
float OVERRIDE_SECONDS_BELOW_PB_SHOW = 0.1;