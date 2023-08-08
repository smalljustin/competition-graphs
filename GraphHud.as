// Common Stuff:
const string DEFAULT_LOG_NAME = Meta::ExecutingPlugin().Name;

void log(const string & in msg) {
    log(DEFAULT_LOG_NAME, msg);
}
void log(const string & in name,
    const string & in msg) {
    print("[\\$669" + name + "\\$z] " + msg);
}


class GraphHud {
    AllRunsScatterPlot allRunsScatterPlot();

    GraphHud() {
        this.OnSettingsChanged();
    }

    void update() {
        allRunsScatterPlot.Update();
    }

    void OnSettingsChanged() {
        m_size = vec2(graph_width, graph_height);
        allRunsScatterPlot.OnSettingsChanged();
    }

    void Render() {
        nvg::BeginPath();
        nvg::RoundedRect(graph_x_offset, graph_y_offset, m_size.x, m_size.y, BorderRadius);
        nvg::FillColor(BackdropColor);
        nvg::Fill();

        nvg::StrokeColor(BorderColor);
        nvg::StrokeWidth(BorderWidth);
        nvg::Stroke();
        allRunsScatterPlot.Render(m_size, LineWidth);
    }
    void OnMouseButton(bool down, int button, int x, int y) {
        allRunsScatterPlot.OnMouseButton(down, button, x, y);
    }
}