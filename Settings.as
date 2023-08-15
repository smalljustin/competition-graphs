[Setting category="General" name="Visible"]
bool g_visible = true;

[Setting category="Display" name="Graph Width" drag min=50 max=2000]
int graph_width = 1000;

[Setting category="Display" name="Graph Height" drag min=50 max=1000]
int graph_height = 150;

[Setting category="Display" name="Graph X Offset" drag min=0 max=4000]
int graph_x_offset = 500;

[Setting category="Display" name="Graph Y Offset" drag min=0 max=2000]
int graph_y_offset = 32;

[Setting category="Display" name="Line Width" drag min=0 max=5]
float LineWidth = 2.0f;

[Setting category="Display" name="Backdrop Color" color]
vec4 BackdropColor = vec4(0, 0, 0, 0.7f);

[Setting category="Display" name="Border color" color]
vec4 BorderColor = vec4(1, 1, 1, 0.5);

[Setting category="Display" name="Border Radius" drag min=0 max=50]
float BorderRadius = 5.0f;

[Setting category="Display" name="Padding" drag min=0 max=50]
float Padding = 2;

[Setting category="General" name="Window Resize and Move Click Zone" min=3 max=20]
float CLICK_ZONE = 10;

[Setting category="Display" name="Point radius" min=0.1 max=10 drag]
float POINT_RADIUS = 1.5;

[Setting category="Histogram" name="Histogram precision value" drag min=0.001 max=0.3]
float HIST_PRECISION_VALUE = 0.02;

[Setting category="General" name="Target fraction of runs to show" drag min=0.1 max=.8]
float TARGET_DISPLAY_PERCENT = 0.875;

[Setting category="Display" name="Histogram run color" color]
vec4 HISTOGRAM_RUN_COLOR = vec4(0.19215686274509805, 0.6235294117647059, 0.5803921568627451, 1.0);

[Setting category="General" name="Max records to pull in" drag min=100 max=8000] 
int MAX_RECORDS = 8000;

[Setting category="General" name="Fraction of runs to show - Focused" drag min=0.1 max=1]
float FOCUSED_RECORD_FRAC = 1;

[Setting category="General" name="Fraction of runs to show - Nonfocused" drag min=0.1 max=1]
float NONFOCUSED_RECORD_FRAC = 0.5;
