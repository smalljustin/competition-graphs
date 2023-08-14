class ScatterHistogram {
    array < HistogramGroup@ >@ histogramGroupArray = array<HistogramGroup@>();

    ChallengeData mapChallenge;

    float precision;
    vec4 valueRange;

    bool WINDOW_MOVING;
    vec2 click_loc(0, 0);

    vec2 min, max;

    vec2 graph_size;

    vec4 pending_v;

    int challenge_id; 

    ScatterHistogram() {}

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
            startnew(CoroutineFunc(this.updateMap));
            updatePbTime();
        }
        renderBackground();
        renderHistogram();
        if (mapChallenge.updated) {
            startnew(CoroutineFunc(this.reloadHistogramData));
            mapChallenge.updated = false;
        }
        handleWindowMoving();
        handleDivs();
        renderMouseHover();
    }

    void handleDivs() {
        for (int i = 0; i < mapChallenge.divs.Length; i++) {
            mapChallenge.divs[i].decrease();
        }
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

    void updateMap() {
        active_map_totd_date = TOTD::GetDateMapWasTOTD_Async(getMapUid());
        challenge_id = GetChallengeForDate(active_map_totd_date.SubStr(0, 10));
        if (challenge_id == 0) {
            is_totd = false;
            return;
        }
        print("Map TOTD date: " + active_map_totd_date + ", challenge ID: " + challenge_id);
        mapChallenge.changeMap(challenge_id, active_map_uuid);
        while (mapChallenge.json_payload.Length == 0) {
            yield();
        }
    }

    int getCutOffTimeAtDiv(int target_time, int precision) {
        for (int i = 0; i < mapChallenge.divs.Length; i++) {
            if (Math::Abs(mapChallenge.divs[i].max_time - target_time) < precision) {
                return Math::Max(mapChallenge.divs[i].max_time, target_time);

            }
        }
        return target_time;
    }


    void reloadHistogramData() {
        if (this.mapChallenge.json_payload.Length == 0) {
            return;
        }
        precision = HIST_PRECISION_VALUE * 1000;
        histogramGroupArray.RemoveRange(0, histogramGroupArray.Length);
        int i;
        for (i = this.mapChallenge.json_payload[0].time; i < this.mapChallenge.json_payload[this.mapChallenge.json_payload.Length - 1].time ;) {
            int res_upper = getCutOffTimeAtDiv(i + precision, precision);
            histogramGroupArray.InsertLast(HistogramGroup(i, res_upper));
            i = res_upper;
        }

        int cur_hga = 0;
        for (int i = 0; i < this.mapChallenge.json_payload.Length; i++) {
            float time = this.mapChallenge.json_payload[i].time;
            HistogramGroup@ hg = histogramGroupArray[cur_hga];

            if (time > hg.lower && time <= hg.upper) {
                hg.DataPointArrays.InsertLast(this.mapChallenge.json_payload[i]);
            } else {
                if (time < hg.lower) {
                    print(time);
                    print(hg.toString());
                    warn("Unexpected behavior! Report this to the dev. This error message will only confuse them, though."); 
                } else {
                    if (cur_hga != histogramGroupArray.Length - 1) {
                        cur_hga += 1;
                        i -= 1; // force it to rerun on the next one
                    }
                }
            }
        }

        reloadValueRange();
    }

    void reloadValueRange() {
        valueRange = vec4(mapChallenge.json_payload[0].time - 100, mapChallenge.json_payload[(int(mapChallenge.json_payload.Length) * 0.9)].time, -1, Math::Max(1, getMaxHistogramCount()));
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


    vec2 TransformToViewBounds(const vec2 & in point,
        const vec2 & in min,
            const vec2 & in max) {
        auto xv = Math::InvLerp(getValueRange().x, getValueRange().y, point.x);
        auto yv = Math::InvLerp(getValueRange().z, getValueRange().w, point.y);
        return vec2(graph_x_offset + Math::Lerp(min.x, max.x, xv), graph_y_offset + Math::Lerp(min.y, max.y, yv));
    }

    void OnSettingsChanged() {
        startnew(CoroutineFunc(this.reloadHistogramData));
    }

    void renderHistogram() {
        if (mapChallenge.json_payload.IsEmpty()) {
            return;
        }
        if (histogramGroupArray is null || histogramGroupArray.IsEmpty() || histogramGroupArray[0] is null) {
            return;
        }
        for (int i = 0; i < histogramGroupArray.Length; i++) {
            array<DataPoint@>@ activeArr = histogramGroupArray[i].DataPointArrays;
            if (activeArr is null || activeArr.Length == 0) {
                continue;
            }
            for (int j = 0; j < activeArr.Length; j++) {
                float x_loc = activeArr[j].time;
                float y_loc = j;

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
                nvg::StrokeWidth((POINT_RADIUS + activeArr[j].focus) ** 2);
                nvg::Stroke();
                nvg::ClosePath();
            }
        }

        if (pbTime != 0) {
            renderLine(pbTime, vec4(1, 1, 1, 1));
        }

        renderLine(mapChallenge.divs[1].max_time, vec4(1, 1, 0, mapChallenge.divs[1].render_fade));

        for (int i = 2; i < mapChallenge.divs.Length; i++) {
            Div@ d = mapChallenge.divs[i];
            renderLine(d.min_time, vec4(1, 1, 0, d.render_fade));
            renderLine(d.max_time, vec4(1, 1, 0, d.render_fade));
        }
    }

    void renderLine(int time, vec4 color) {
        if (getValueRange().w == 0) {
            return;
        }
        nvg::BeginPath();
        nvg::MoveTo(TransformToViewBounds(ClampVec2(vec2(time, valueRange.w), getValueRange()), min, max));
        nvg::LineTo(TransformToViewBounds(ClampVec2(vec2(time, valueRange.z), getValueRange()), min, max));
        nvg::StrokeWidth(1);
        nvg::StrokeColor(color);
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
        if (mapChallenge.json_payload.Length == 0) {
            return;
        }

        vec2 mouse_pos = UI::GetMousePos();
        
        if ((mouse_pos.x < graph_x_offset || mouse_pos.x > graph_width + graph_x_offset) || 
            (mouse_pos.y < graph_y_offset || mouse_pos.y > graph_height + graph_y_offset)) {
                return;
            }

        if (histogramGroupArray is null || histogramGroupArray.Length == 0) {
            return;
        }

        string text; 

        float mouse_hover_x = Math::Lerp(valueRange.x, valueRange.y, Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, mouse_pos.x));
        float mouse_hover_y = Math::Lerp(valueRange.w, valueRange.z, Math::InvLerp(graph_y_offset, graph_y_offset + graph_height, mouse_pos.y));

        HistogramGroup@ histGroup;
        // find the closest datapoint to the mouse cursor

        for (int i = 0; i < histogramGroupArray.Length; i++) {
            if (histogramGroupArray[i] !is null && histogramGroupArray[i].lower <= mouse_hover_x && histogramGroupArray[i].upper > mouse_hover_x) {
                @histGroup = histogramGroupArray[i];
            }
            /* unrelated decay */
            for (int j = 0; j < histogramGroupArray[i].DataPointArrays.Length; j++) {
                histogramGroupArray[i].DataPointArrays[j].decrease();
            }
        }

        if (histGroup is null || histGroup.DataPointArrays is null || histGroup.DataPointArrays.IsEmpty()) {
            return;
        }
        int player_idx = Math::Clamp(mouse_hover_y, float(0), float(histGroup.DataPointArrays.Length - 1));
        histGroup.DataPointArrays[player_idx].increase(); 
        mapChallenge.divs[histGroup.DataPointArrays[player_idx].div].increase();

        text = "\tTime: " + Text::Format("%.3f", float(histGroup.DataPointArrays[player_idx].time) / 1000);
        text += "\tDiv: " + tostring(histGroup.DataPointArrays[player_idx].div);
        text += "\tRank: " + Text::Format("%d", histGroup.DataPointArrays[player_idx].rank);

        nvg::BeginPath();
        nvg::FillColor(vec4(.9, .9, .9, 1));
        nvg::Text(mouse_pos, text);
        nvg::Stroke();
        nvg::ClosePath();
    }

    
}