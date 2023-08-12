class ScatterHistogram {
    array < DataPoint > @ data;
    array < HistogramGroup > histogramGroupArray();

    DataPoint @ fastest_run = DataPoint();
    DataPoint @ slowest_run = DataPoint();

    ChallengeData mapChallenge;

    float precision;

    vec4 valueRange;

    bool WINDOW_MOVING;
    vec2 click_loc(0, 0);

    vec2 min, max;

    vec2 graph_size;

    vec4 pending_v;

    ScatterHistogram() {}

    ScatterHistogram(ChallengeData @ c) {
        this.mapChallenge.json_payload = c.json_payload;
    }

    vec4 getValueRange() {
        // Returns the value range, offset by the current mouse position and click location.
        if (!WINDOW_MOVING) {
            return valueRange;
        }
        vec2 current_loc = UI::GetMousePos();
        pending_v = valueRange;
        float click_x_offset = Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, click_loc.x);
        float click_y_offset = Math::InvLerp(graph_x_offset, graph_y_offset + graph_width, click_loc.y);

        float current_x_offset = Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, current_loc.x);
        float current_y_offset = Math::InvLerp(graph_x_offset, graph_y_offset + graph_width, current_loc.y);

        float realized_x_offset = Math::Lerp(0, valueRange.y - valueRange.x, (current_x_offset - click_x_offset));
        float realized_y_offset = Math::Lerp(0, valueRange.w - valueRange.z, (current_y_offset - click_y_offset));

        pending_v -= vec4(realized_x_offset, realized_x_offset, -realized_y_offset, -realized_y_offset);

        return pending_v;
    }

    void updatePbTime() {
        auto app = cast<CTrackMania>(GetApp());
        auto network = cast<CTrackManiaNetwork>(app.Network);
        auto scoreMgr = network.ClientManiaAppPlayground.ScoreMgr;
        auto userMgr = network.ClientManiaAppPlayground.UserMgr;
        MwId userId;
        if (userMgr.Users.Length > 0) {
        userId = userMgr.Users[0].Id;
        } else {
        userId.Value = uint(-1);
        }
        pbTime = scoreMgr.Map_GetRecord_v2(userId, active_map_uuid, "PersonalBest", "", "TimeAttack", "");
    }


    void render() {
        float padding = 0;
        min = vec2(padding, graph_height - padding);
        max = vec2(graph_width - padding, padding);

        if (active_map_uuid != getMapUid()) {
            active_map_uuid = getMapUid();
            is_totd = true;
            mapChallenge.changeMap(active_map_uuid);
            startnew(CoroutineFunc(this.updateFastestRun));
            updatePbTime();
        }
        renderBackground();
        renderHistogram();
        if (mapChallenge.updated) {
            reloadHistogramData();
            mapChallenge.updated = false;
        }
        handleWindowMoving();
        renderMouseHover();
    }

    void renderBackground() {
        nvg::BeginPath();
        nvg::RoundedRect(graph_x_offset, graph_y_offset, m_size.x, m_size.y, BorderRadius);
        nvg::FillColor(BackdropColor);
        nvg::Fill();

        nvg::StrokeColor(BorderColor);
        nvg::StrokeWidth(BorderWidth);
        nvg::Stroke();
    }

    void updateFastestRun() {
        while (mapChallenge.json_payload.Length == 0) {
            yield();
        }
        fastest_run = mapChallenge.json_payload[0];
        reloadHistogramData();
    }

    void reloadHistogramData() {
        if (this.mapChallenge.json_payload.Length == 0) {
            return;
        }
        precision = HIST_PRECISION_VALUE * 1000;
        histogramGroupArray = array < HistogramGroup > ();
        for (int i = fastest_run.time; i < this.mapChallenge.json_payload[this.mapChallenge.json_payload.Length - 1].time; i += precision) {
            histogramGroupArray.InsertLast(HistogramGroup(i, i + precision));
        }

        int end_pos = this.mapChallenge.json_payload.Length - HIST_RUN_START_OFFSET;
        int start_pos = Math::Max(0, end_pos - HIST_RUNS_TO_SHOW);

        for (int i = start_pos; i < end_pos; i++) {
            float time = this.mapChallenge.json_payload[i].time;
            int idx = (time - fastest_run.time) / precision;
            if (idx >= histogramGroupArray.Length) {
                continue;
            }
            histogramGroupArray[idx].DataPointArrays.InsertLast(this.mapChallenge.json_payload[i]);
        }
        reloadValueRange();
    }

    void reloadValueRange() {
        valueRange = vec4(mapChallenge.json_payload[0].time, mapChallenge.json_payload[0].time * GET_SLOWEST_RUN_CUTOFF(), 0, getMaxHistogramCount());
    }
    
    int getMaxHistogramCount() {
        float m = 0; 
        for (int i = 0; i < histogramGroupArray.Length; i++) {
            m = Math::Max(histogramGroupArray[i].DataPointArrays.Length, m);
        }
        return m;
    }

    int getMaxRank(HistogramGroup @histogramGroup) {
        if (histogramGroup.maxRank != -1) {
            return histogramGroup.maxRank;
        } else {
            histogramGroup.maxRank = getMaxRank(histogramGroup.DataPointArrays);
            return histogramGroup.maxRank;
        }
    }

    int getMinRank(HistogramGroup @histogramGroup) {
        if (histogramGroup.minRank != -1) {
            return histogramGroup.minRank;
        } else {
            histogramGroup.minRank = getMinRank(histogramGroup.DataPointArrays);
            return histogramGroup.minRank;
        }
    }

    int getMaxRank(array<DataPoint@> arr) {
        int max_run_id = -1;
        for (int i = 0; i < arr.Length; i++) {
            max_run_id = Math::Max(max_run_id, arr[i].rank);
        }
        return max_run_id; 
    }

    int getMinRank(array<DataPoint@> arr) {
        int min_run_id = 10 ** 6;
        for (int i = 0; i < arr.Length; i++) {
            min_run_id = Math::Min(min_run_id, arr[i].rank);
        }
        return min_run_id;
    }


    float GET_SLOWEST_RUN_CUTOFF() {
        if (HISTOGRAM_VIEW) {
            return SLOW_RUN_CUTOFF_HIST;
        } else {
            return SLOW_RUN_CUTOFF_SCATTER;
        }
    }

    vec2 TransformToViewBounds(const vec2 & in point,
        const vec2 & in min,
            const vec2 & in max) {
        auto xv = Math::InvLerp(getValueRange().x, getValueRange().y, point.x);
        auto yv = Math::InvLerp(getValueRange().z, getValueRange().w, point.y);
        return vec2(graph_x_offset + Math::Lerp(min.x, max.x, xv), graph_y_offset + Math::Lerp(min.y, max.y, yv));
    }

    void OnSettingsChanged() {
        this.reloadHistogramData();
    }


    void renderHistogram() {
        if (mapChallenge.json_payload.IsEmpty()) {
            return;
        }
        for (int i = 0; i < histogramGroupArray.Length; i++) {
            for (int j = 0; j < histogramGroupArray[i].DataPointArrays.Length; j++) {
                array<DataPoint@>@ activeArr = histogramGroupArray[i].DataPointArrays;
                float x_loc = activeArr[j].time;
                float y_loc =  Math::Lerp(0, histogramGroupArray[i].DataPointArrays.Length,
                    Math::InvLerp(
                        getMinRank(@histogramGroupArray[i]),
                        getMaxRank(@histogramGroupArray[i]),
                        activeArr[j].rank));

                if (histogramGroupArray[i].DataPointArrays.Length == 1) {
                    y_loc = 0;
                }

                vec4 color = HISTOGRAM_RUN_COLOR;

                color.x += 0.05 * activeArr[j].div;
                color.y += 0.05 * activeArr[j].div ** 2;
                color.z += 0.05 * activeArr[j].div ** 3;

                color.x %= 1;
                color.y %= 1;
                color.z %= 1;

                
                
                nvg::BeginPath();
                nvg::Circle(
                    TransformToViewBounds(ClampVec2(vec2(x_loc, y_loc), getValueRange()), min, max),
                    POINT_RADIUS
                );
                nvg::StrokeColor(color);
                nvg::StrokeWidth(POINT_RADIUS ** 2);
                nvg::Stroke();
                nvg::ClosePath();
            }
        }

        nvg::BeginPath();
        nvg::MoveTo(TransformToViewBounds(ClampVec2(vec2(pbTime, valueRange.w), getValueRange()), min, max));
        nvg::LineTo(TransformToViewBounds(ClampVec2(vec2(pbTime, valueRange.z), getValueRange()), min, max));
        nvg::StrokeWidth(1);
        nvg::StrokeColor(vec4(1, 1, 1, 1));
        nvg::Stroke();
        nvg::ClosePath();

        
    }

    vec2 ClampVec2(const vec2 & in val, const vec4 & in bounds) {
        return vec2(Math::Clamp(val.x, bounds.x, bounds.y), Math::Clamp(val.y, bounds.z, bounds.w));
    }


    void handleWindowMoving() {
        if (!WINDOW_MOVING) {
            return;
        }
    }

    void OnMouseButton(bool down, int button, int x, int y) {
        if (button == 1) {
            reloadValueRange();
            return;
        }
        WINDOW_MOVING = down;
        click_loc = vec2(x, y);
        if (!down) {
            valueRange = pending_v;
        }
    }

    void renderMouseHover() {
        vec2 mouse_pos = UI::GetMousePos();
        string text; 

        float mouse_hover_x = Math::Lerp(valueRange.x, valueRange.y, Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, mouse_pos.x));
        float mouse_hover_y = Math::Lerp(valueRange.z, valueRange.w, Math::InvLerp(graph_y_offset, graph_y_offset + graph_height, mouse_pos.y));

        int idx = (mouse_hover_x - fastest_run.time) / precision;

        if (idx < 0 || idx >= histogramGroupArray.Length) {
            return;
        }

        HistogramGroup@ histGroup = histogramGroupArray[idx];
        if (histGroup is null || histGroup.DataPointArrays.IsEmpty()) {
            return;
        }

        // find the closest datapoint to the mouse cursor

        
        DataPoint@ closestPoint = histGroup.DataPointArrays[0];
        DataPoint@ curPoint = histGroup.DataPointArrays[0];
        float max_dist = Math::Sqrt((curPoint.time - mouse_hover_x) ** 2 + (0 - mouse_hover_y) ** 2);

        for (int i = 0; i < histGroup.DataPointArrays.Length; i++) { 
            if (histGroup.DataPointArrays is null) {
                return;
            }
            curPoint = histGroup.DataPointArrays[0];
            float cur_dist = Math::Sqrt((curPoint.time - mouse_hover_x) ** 2 + (i - mouse_hover_y) ** 2);
            
            if (cur_dist < max_dist) {
                closestPoint = curPoint;
                max_dist = cur_dist;
            }
        }

        text = "Time: " + Text::Format("%.3f", float(mapChallenge.divs[closestPoint.div].min_time) / 1000) + " to " + Text::Format("%.3f", float(mapChallenge.divs[closestPoint.div].max_time) / 1000);
        text += "\tDiv: " + tostring(closestPoint.div);


        nvg::BeginPath();
        // nvg::Rect(mouse_pos - vec2(0, nvg::TextBounds(text).y), nvg::TextBounds(text));
        nvg::FillColor(vec4(.9, .9, .9, 1));
        // nvg::Fill();
        nvg::Text(mouse_pos, text);
        nvg::Stroke();
        nvg::ClosePath();
    }

    
}