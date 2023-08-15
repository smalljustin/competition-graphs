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

    bool focused;

    float BorderWidth = 0;

    float curPointRadius = POINT_RADIUS;

    CLICK_LOCATION curClickLocEnum = CLICK_LOCATION::NOEDGE;

    ScatterHistogram() {}

    array<DataPoint@> dataPointsToPrint;

    array<vec2> dataPointsToPrintLocations;
    
    bool shouldDecay = false;

    void printDataPoints() {
        for (int i = 0; i < dataPointsToPrint.Length; i++) {
            _renderDataPointText(dataPointsToPrint[i], dataPointsToPrintLocations[i]);
        }

        dataPointsToPrint.RemoveRange(0, dataPointsToPrint.Length);
        dataPointsToPrintLocations.RemoveRange(0, dataPointsToPrintLocations.Length);
    }

    vec4 getValueRange() {
        // Returns the value range, offset by the current mouse position and click location.
        if (!WINDOW_MOVING) {
            return valueRange;
        }
        vec2 current_loc = UI::GetMousePos();
        pending_v = valueRange;
        float click_x_offset = Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, click_loc.x);
        float click_y_offset = Math::InvLerp(graph_y_offset, graph_y_offset + graph_height, click_loc.y);

        float current_x_offset = Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, current_loc.x);
        float current_y_offset = Math::InvLerp(graph_y_offset, graph_y_offset + graph_height, current_loc.y);

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
        min = vec2(curPointRadius, graph_height - curPointRadius);
        max = vec2(graph_width - curPointRadius, curPointRadius);

        if (active_map_uuid != getMapUid()) {
            active_map_uuid = getMapUid();
            is_totd = true;
            startnew(CoroutineFunc(this.updateMap));
            updatePbTime();
        }
        if (mapChallenge.updated) {
            startnew(CoroutineFunc(this.reloadHistogramData));
            mapChallenge.updated = false;
        }
        renderBackground();
        renderHistogram();

        renderMouseHover();
        printDataPoints();
        handleWindowMoving();
        handleWindowResize();
        handleDivs();
        handlePointDecay();
    }

    void handlePointDecay() {
        vec4 vr = getValueRange();
        HistogramGroup@ histogramGroup;

        if (!this.shouldDecay) {
            return;
        }

        bool decayDone = false;

        for (int i = 0; i < histogramGroupArray.Length; i++) {
            @histogramGroup = @histogramGroupArray[i];
            for (int j = 0; j < histogramGroup.DataPointArrays.Length; j++) {
                decayDone = histogramGroup.DataPointArrays[j].decrease() || decayDone;
                if (!focused) {
                    histogramGroup.DataPointArrays[j].clicked = false;
                }
            }
        }
        this.shouldDecay = decayDone;
    }

    void handleDivs() {
        for (int i = 0; i < mapChallenge.divs.Length; i++) {
            mapChallenge.divs[i].decrease();
        }
    }

    void renderBackground() {
        nvg::BeginPath();
        nvg::RoundedRect(
            graph_x_offset - curPointRadius ** 2,
            graph_y_offset - curPointRadius ** 2,
            graph_width + curPointRadius ** 2,
            graph_height + curPointRadius ** 2 * 2,
        BorderRadius);
        nvg::FillColor(BackdropColor);
        nvg::Fill();

        nvg::StrokeColor(BorderColor);
        nvg::StrokeWidth(BorderWidth);
        nvg::Stroke();
        nvg::ClosePath();
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

    void handleWindowResize() {
        if (curClickLocEnum == CLICK_LOCATION::NOEDGE) {
            return;
        }
        
        vec2 mouse_pos = UI::GetMousePos();
        if (curClickLocEnum == CLICK_LOCATION::TLC ) {
            graph_x_offset = mouse_pos.x;
            graph_y_offset = mouse_pos.y;
            return;
        }

        if (curClickLocEnum == CLICK_LOCATION::LEFTEDGE) {
            graph_x_offset = mouse_pos.x;
        }

        if (curClickLocEnum == CLICK_LOCATION::TOPEDGE) {
            graph_y_offset = mouse_pos.y;
        }

        if (curClickLocEnum == CLICK_LOCATION::RIGHTEDGE || curClickLocEnum == CLICK_LOCATION::TRC || curClickLocEnum == CLICK_LOCATION::BRC) {
            graph_width = mouse_pos.x - graph_x_offset;
        }

        if (curClickLocEnum == CLICK_LOCATION::BOTTOMEDGE || curClickLocEnum == CLICK_LOCATION::BLC || curClickLocEnum == CLICK_LOCATION::BRC) {
            graph_height = mouse_pos.y - graph_y_offset;
        }


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
        for (int i = 0; i < Math::Min(this.mapChallenge.json_payload.Length, MAX_RECORDS); i++) {
            float time = this.mapChallenge.json_payload[i].time;
            HistogramGroup@ hg = @histogramGroupArray[cur_hga];

            if (time >= hg.lower && time <= hg.upper) {
                hg.DataPointArrays.InsertLast(@this.mapChallenge.json_payload[i]);
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
        curPointRadius = POINT_RADIUS;
        valueRange = vec4(mapChallenge.json_payload[0].time - 100, mapChallenge.json_payload[(int(mapChallenge.json_payload.Length) * TARGET_DISPLAY_PERCENT)].time, -1, Math::Max(1, getMaxHistogramCount()));
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
        startnew(CoroutineFunc(this.mapChallenge.load_external));
        startnew(CoroutineFunc(this.reloadHistogramData));
    }

    void renderHistogram() {
        if (mapChallenge.json_payload.IsEmpty()) {
            return;
        }
        if (histogramGroupArray is null || histogramGroupArray.IsEmpty() || histogramGroupArray[0] is null) {
            return;
        }

        float rf; 

        if (focused) {
            rf = FOCUSED_RECORD_FRAC;
        } else {
            rf = NONFOCUSED_RECORD_FRAC; 
        }

        float count_val = 1 - rf / 3;

        vec4 vr = getValueRange();

        for (int i = 0; i < histogramGroupArray.Length; i++) {
            HistogramGroup@ activeGroup = @histogramGroupArray[i];
            array<DataPoint@>@ activeArr = @activeGroup.DataPointArrays;
            if (activeArr is null || activeArr.Length == 0) {
                continue;
            }
            if ((focused && activeGroup.upper < vr.x) || activeGroup.lower > vr.y) {
                continue;
            }

            for (int j = 0; j < activeArr.Length; j++) {
                float x_loc = activeArr[j].time;
                float y_loc = j;

                if (Math::IsInf(x_loc) || Math::IsNaN(x_loc)) {
                    continue;
                }

                if (Math::IsInf(y_loc) || Math::IsNaN(y_loc)) {
                    continue;
                }

                if (activeArr.Length == 1) {
                    y_loc = 0;
                }

                count_val += rf;
                if (count_val < 1) {
                    continue;
                }
                count_val -= 1;

                if (j < vr.z || j > vr.w) {
                    continue;
                }

                activeArr[j].visible = true;

                vec4 color = HISTOGRAM_RUN_COLOR;

                color.x += 0.05 * activeArr[j].div;
                color.y += 0.05 * activeArr[j].div ** 2;
                color.z += 0.05 * activeArr[j].div ** 3;

                color.x %= 1;
                color.y %= 1;
                color.z %= 1;
                
                if (activeArr[j].clicked) {
                    nvg::BeginPath();
                    nvg::Circle(
                        TransformToViewBounds(ClampVec2(vec2(x_loc, y_loc), vr), min, max),
                        curPointRadius + 2
                    );

                    nvg::StrokeColor(vec4(1, 1, 1, 1));
                    nvg::StrokeWidth(curPointRadius ** 2);
                    nvg::Stroke();
                    nvg::ClosePath();
                    renderDataPointText(activeArr[j], TransformToViewBounds(ClampVec2(vec2(x_loc, y_loc), getValueRange()), min, max));
                }

                nvg::BeginPath();
                nvg::Circle(
                    TransformToViewBounds(ClampVec2(vec2(x_loc, y_loc), vr), min, max),
                    curPointRadius
                );

                nvg::StrokeColor(color);
                nvg::StrokeWidth((curPointRadius + activeArr[j].focus) ** 2);
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
        vec4 vr = getValueRange();

        if (vr.w == 0) {
            return;
        }
        nvg::BeginPath();
        nvg::MoveTo(TransformToViewBounds(ClampVec2(vec2(time, vr.w), vr), min, max));
        nvg::LineTo(TransformToViewBounds(ClampVec2(vec2(time, vr.z), vr), min, max));
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
        if (!down) {
            if (WINDOW_MOVING) {
                valueRange = pending_v;
                WINDOW_MOVING = down;
            }
        }

        if (!down || (x > graph_x_offset - CLICK_ZONE && x < graph_x_offset + graph_width + CLICK_ZONE && y > graph_y_offset - CLICK_ZONE && y < graph_y_offset + graph_height + CLICK_ZONE)) {
            if (button == 1) {
                reloadValueRange();
                return;
            }
            if (down)
                focused = true;
            
            // Check if we have a point active (i.e., at 100% focus):

            DataPoint@ activePoint;
            for (int i = 0; i < histogramGroupArray.Length; i++) {
                for (int j = 0; j < histogramGroupArray[i].DataPointArrays.Length; j++) {
                    if (histogramGroupArray[i].DataPointArrays[j].focus == .9) {
                        @activePoint = histogramGroupArray[i].DataPointArrays[j];
                    }
                }
            }
            if (activePoint is null) {
                // Then check if we're clicking an edge
                CLICK_LOCATION clickLocType = getClickLocEnum(x, y);
                if (clickLocType != CLICK_LOCATION::NOEDGE) {
                    if (down) {
                        curClickLocEnum = clickLocType;
                    } else {
                        curClickLocEnum = CLICK_LOCATION::NOEDGE;
                    }
                    return;
                }
                // Otherwise, pan the graph
                WINDOW_MOVING = down;
                click_loc = vec2(x, y);

            } else {
                if (down) {
                    activePoint.clicked = !activePoint.clicked;
                    shouldDecay = true;
                }
            }
        } else {
            focused = false;
            shouldDecay = true;
        }
    }

    CLICK_LOCATION getClickLocEnum(int x, int y) {
        if (WINDOW_MOVING) {
            return CLICK_LOCATION::NOEDGE;
        }

        bool isLeftEdge = isNear(x, graph_x_offset - curPointRadius ** 2, CLICK_ZONE);
        bool isRightEdge = isNear(x, graph_x_offset + graph_width + curPointRadius ** 2, CLICK_ZONE);
        bool isTopEdge = isNear(y, graph_y_offset - curPointRadius ** 2, CLICK_ZONE);
        bool isBottomEdge = isNear(y, graph_y_offset + graph_height + curPointRadius ** 2, CLICK_ZONE);

        if (isLeftEdge && isTopEdge) {
            return CLICK_LOCATION::TLC;
        }
        if (isLeftEdge && isBottomEdge) {
            return CLICK_LOCATION::BLC;
        }
        if (isRightEdge && isTopEdge) {
            return CLICK_LOCATION::TRC;
        }
        if (isRightEdge && isBottomEdge) {
            return CLICK_LOCATION::BRC;
        }

        if (isLeftEdge) {
            return CLICK_LOCATION::LEFTEDGE;
        }
        if (isRightEdge) {
            return CLICK_LOCATION::RIGHTEDGE;
        }
        if (isTopEdge) {
            return CLICK_LOCATION::TOPEDGE;
        }
        if (isBottomEdge) {
            return CLICK_LOCATION::BOTTOMEDGE;
        }
        return CLICK_LOCATION::NOEDGE;
    }

    bool isNear(int test, int ref, int window) {
        return Math::Abs(test - ref) < window;
    }

    void renderMouseHover() {
        if (mapChallenge.json_payload.Length == 0) {
            return;
        }

        vec4 vr = getValueRange();

        vec2 mouse_pos = UI::GetMousePos();

        if (getClickLocEnum(mouse_pos.x, mouse_pos.y) != CLICK_LOCATION::NOEDGE) {
            BorderWidth = Math::Min(BorderWidth + 0.5, CLICK_ZONE / 2);
        } else {
            BorderWidth = Math::Max(BorderWidth - 0.5, 0);
        }

        if ((mouse_pos.x < graph_x_offset || mouse_pos.x > graph_width + graph_x_offset) || 
            (mouse_pos.y < graph_y_offset || mouse_pos.y > graph_height + graph_y_offset)) {
                return;
            }

        if (histogramGroupArray is null || histogramGroupArray.Length == 0) {
            return;
        }

        string text; 

        float mouse_hover_x = Math::Lerp(vr.x, vr.y, Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, mouse_pos.x));
        float mouse_hover_y = Math::Lerp(vr.w, vr.z, Math::InvLerp(graph_y_offset, graph_y_offset + graph_height, mouse_pos.y - curPointRadius ** 2));

        HistogramGroup@ histGroup;
        // find the closest datapoint to the mouse cursor

        bool matched = false;

        for (int i = 0; !matched && i < histogramGroupArray.Length; i++) {
            if (histogramGroupArray[i] !is null && histogramGroupArray[i].lower <= mouse_hover_x && histogramGroupArray[i].upper > mouse_hover_x) {
                matched = true;
            }
            if (matched && histogramGroupArray[i].DataPointArrays.Length > 0) {
                for (int j = 0; j < histogramGroupArray[i].DataPointArrays.Length; j++) {
                    if (histogramGroupArray[i].DataPointArrays[j].visible && Math::Abs(mouse_hover_y - j) < 4 && mouse_hover_y >= j) {
                        @histGroup = histogramGroupArray[i];
                        break;
                    }
                }
            if (histGroup is null) {
                matched = false;
            }
            }
        }

        if (histGroup is null || histGroup.DataPointArrays is null || histGroup.DataPointArrays.IsEmpty()) {
            return;
        }
        int player_idx = Math::Clamp(mouse_hover_y, float(0), float(histGroup.DataPointArrays.Length - 1));

        DataPoint@ selectedPoint;

        for (int i = player_idx; i >= 0; i--) {
            if (histGroup.DataPointArrays[player_idx].visible) {
                @selectedPoint = histGroup.DataPointArrays[player_idx];
                break;
            }
        }

        if (selectedPoint is null) {
            return;
        }

        selectedPoint.increase(); 
        mapChallenge.divs[selectedPoint.div].increase();
        this.shouldDecay = true;
    }

    void renderDataPointText(DataPoint@ selectedPoint, vec2 pos) {
        dataPointsToPrint.InsertLast(selectedPoint);
        dataPointsToPrintLocations.InsertLast(pos);
    }

    void _renderDataPointText(DataPoint@ selectedPoint, vec2 pos) {
        pos.y -= curPointRadius * 2;
        string text = "Rank: " + Text::Format("%d", selectedPoint.rank);
        text += ", Div: " + tostring(selectedPoint.div);
        text += " - " + Text::Format("%.3f", float(selectedPoint.time) / 1000);

        vec2 textSize = nvg::TextBounds(text);

        vec2 textPos = pos; 
        textPos.y -= textSize.y;
        textPos -= vec2(Padding, Padding);
        textSize += 2 * vec2(Padding, Padding);

        nvg::BeginPath();
        nvg::RoundedRect(textPos, textSize, BorderRadius);

        vec4 c = BackdropColor;
        c.w = 0.9;
        nvg::FillColor(c);
        nvg::Fill();
        nvg::ClosePath();

        nvg::BeginPath();
        nvg::FillColor(vec4(.9, .9, .9, 1));
        nvg::Text(pos, text);
        nvg::Stroke();
        nvg::ClosePath();
        
    }

    // x scroll not implemented because i don't have a mouse that can do that 
    // if that is a feature you care about please paypal me k thx bye
    void OnMouseWheel(int y) {
        float offset = (y < 0 ? -1 : 1) * Math::InvLerp(-720, 720, y) / 10;
        vec2 mouse_pos = UI::GetMousePos();

        if ((mouse_pos.x < graph_x_offset || mouse_pos.x > graph_width + graph_x_offset) || 
            (mouse_pos.y < graph_y_offset || mouse_pos.y > graph_height + graph_y_offset)) {
                return;
            }

        float xOffset = Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, mouse_pos.x);
        float yOffset = Math::InvLerp(graph_y_offset, graph_y_offset + graph_height, mouse_pos.y);
        
        
        float xdiff = valueRange.y - valueRange.x;
        float ydiff = valueRange.w - valueRange.z;

        curPointRadius = curPointRadius + curPointRadius * (offset / 2);

        valueRange.x = valueRange.x + xdiff * offset * xOffset;
        valueRange.y = valueRange.y - xdiff * offset * (1 - xOffset);
        valueRange.z = valueRange.z + ydiff * offset * (1 - yOffset);
        valueRange.w = valueRange.w - ydiff * offset * yOffset;

    }
    
}

enum CLICK_LOCATION {
    TOPEDGE,
    LEFTEDGE,
    BOTTOMEDGE,
    RIGHTEDGE,
    TLC,
    BLC,
    BRC,
    TRC,
    NOEDGE
}