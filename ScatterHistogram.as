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

    float BorderWidth = 0;

    float curPointRadius = POINT_RADIUS;

    CLICK_LOCATION curClickLocEnum = CLICK_LOCATION::NOEDGE;

    ScatterHistogram() {}


    bool shouldDecay = false;
    int curRunStartTime = 0;

    bool reloadHistogramDataLock = false;
    bool reloadHistogramRenderLock = false;

    array<vec2> @rp_pos_arr = @array<vec2>();
    array<float> @rp_size_arr = @array<float>();
    array<float> @rp_size_offset_arr = @array<float>();
    array<vec4> @rp_color_arr = @array<vec4>();
    array<vec4> @rp_fill_color_arr = @array<vec4>();
    array<bool> @rp_point_selected_arr = @array<bool>();

    array<DataPoint@> @dataPointsToDecay = @array<DataPoint@>(); 
    array<DataPoint@> @dataPointsToPrint = @array<DataPoint@>();


    int rpidxVal;

    vec4 vr;

    float BARHIST_OPACITY = 1;
    float POINTHIST_OPACITY = 0; 

    float start_size_offset = 1;
    float size_offset = 1;

    vec2 helpTextLocation;

    void renderHelpText() {
        if (!SHOW_HELP_TEXT) {
            return;
        }

        if (start_size_offset == 0) {
            return;
        }

        array<string> helpText;

        helpText.InsertLast("COTD Qualification Grapher");

        if (size_offset / start_size_offset > 1.5) {
            helpText.InsertLast("Click and drag (off a bar) to pan");
            helpText.InsertLast("Use your mouse wheel to zoom.");
            helpText.InsertLast("Click/drag the border to resize/move");
            helpText.InsertLast("Click dots for more info.");
            helpText.InsertLast("Right click to remove labels");   
            helpText.InsertLast("Disable this text in settings.");   
        } else {
            helpText.InsertLast("Zoom in for usage (mouse wheel)");
        }

   
        vec2 offset(0);

        for (int i = 0; i < helpText.Length; i++) {
        renderText(helpText[i],
        TransformToViewBounds(
            helpTextLocation,
            min,
            max) + offset, false);
            offset.y += 16;
        }

    }
    


    void printDataPoints() {
        for (uint i = 0; i < dataPointsToPrint.Length; i++) {
            if (dataPointsToPrint[i] !is null)
                renderDataPointText(dataPointsToPrint[i]);
        }
    }

    vec4 getValueRange() {
        // Returns the value range, offset by the current mouse position and click location.
        if (!WINDOW_MOVING) {
            return valueRange;
        }
        vec2 current_loc = UI::GetMousePos();
        float click_x_offset = Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, int(click_loc.x));
        float click_y_offset = Math::InvLerp(graph_y_offset, graph_y_offset + graph_height, int(click_loc.y));

        float current_x_offset = Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, int(current_loc.x));
        float current_y_offset = Math::InvLerp(graph_y_offset, graph_y_offset + graph_height, int(current_loc.y));

        float realized_x_offset = Math::Lerp(0, valueRange.y - valueRange.x, (current_x_offset - click_x_offset));
        float realized_y_offset = Math::Lerp(0, valueRange.w - valueRange.z, (current_y_offset - click_y_offset));

        pending_v = valueRange - vec4(realized_x_offset, realized_x_offset, -realized_y_offset, -realized_y_offset);
        return pending_v;
    }

    void updatePbTime() {
        int startTime = getPlayerStartTime();
        if (startTime == curRunStartTime) {
            return;
        }
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
        curRunStartTime = startTime;
    }

    void removeDataPointFromDataPointsToPrint(DataPoint@ dp) {
        for (uint i = 0; i < this.dataPointsToPrint.Length; i++) {
            if (this.dataPointsToPrint[i] is dp) {
                @this.dataPointsToPrint[i] = null;
            }
            rp_fill_color_arr[dp.curRenderIdx] = 0;
            dp.clicked = false;
        }
    }


    void render() {
        min = vec2(curPointRadius, graph_height - curPointRadius);
        max = vec2(graph_width - curPointRadius, curPointRadius);

        if (active_map_uuid != getMapUid()) {
            active_map_uuid = getMapUid();
            if (active_map_uuid == "") {
                this.mapChallenge.terminate();
            }
            is_totd = true;
            startnew(CoroutineFunc(this.updateMap));
        }
        if (!is_totd) {
            return;
        }

        vr = getValueRange();

        setBarHistOpacity();

        renderBackground();
        renderHistogram();
        renderMouseHover();
        renderDivs();
        printDataPoints();
        renderHelpText();
        renderLoading();

        handleWindowMoving();
        handleWindowResize();
        handleDivs();
        handlePointDecay();
        updatePbTime();
        startnew(CoroutineFunc(this.handleClickedDecay));

    }

    void renderLoading() {
        if (!this.mapChallenge.updateComplete) {
            string text = "[" + tostring(challenge_id) + "] - " "COTD Grapher is loading";
            for (int i = 1; i < (Time::Now / 600) % 4; i++) {
                text += ".";
            }
            renderText(text,
            vec2(graph_x_offset + 0.2 * graph_width, graph_y_offset + 0.2 * graph_height),
             false);
        }
    }

    void handlePointDecay() {
        if (this.dataPointsToDecay.IsEmpty()) {
            return;
        }

        for (uint i = 0; i < this.dataPointsToDecay.Length; i++) {
            if (this.dataPointsToDecay[i] is null) {
                continue;
            }
            if (this.dataPointsToDecay[i].decrease()) {
                int idx = this.dataPointsToDecay[i].curRenderIdx;
                if (rp_size_offset_arr.Length >= idx) {
                    rp_size_offset_arr[idx] = this.dataPointsToDecay[i].focus;
                }
                continue;
            } else {
                int idx = this.dataPointsToDecay[i].curRenderIdx;
                if (rp_point_selected_arr.Length >= idx) {
                    rp_point_selected_arr[this.dataPointsToDecay[i].curRenderIdx] = false;
                }
                @this.dataPointsToDecay[i] = null;
            }
        }
    }

    void cleanPointDecay() {
        array<DataPoint@> @newArr = array<DataPoint@>();
        for (uint i = 0; i < dataPointsToDecay.Length; i++) {
            if (dataPointsToDecay[i] !is null) {
                newArr.InsertLast(dataPointsToDecay[i]);
            }
            YieldByTime();
        }
        @dataPointsToDecay = @newArr;
    }

    void handleClickedDecay() {
        for (uint i = 0; i < dataPointsToPrint.Length; i++) {
            if (dataPointsToPrint[i] !is null && !dataPointsToPrint[i].clicked) {
                @dataPointsToPrint[i] = null;
            }
            YieldByTime();
        }
    }

    void handleDivs() {
        for (uint i = 0; i < this.mapChallenge.divs.Length; i++) {
            this.mapChallenge.divs[i].decrease();
        }
    }

    void renderBackground() {
        nvg::BeginPath();
        nvg::RoundedRect(
            graph_x_offset - curPointRadius,
            graph_y_offset - curPointRadius,
            graph_width + curPointRadius,
            graph_height + curPointRadius,
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
        if (active_map_totd_date == "") {
            is_totd = false;
        }
        challenge_id = GetChallengeForDate(active_map_totd_date.SubStr(0, 10));
        if (challenge_id == 0) {
            is_totd = false;
            return;
        }
        print("Map TOTD date: " + active_map_totd_date + ", challenge ID: " + challenge_id);

        if (this.mapChallenge !is null) {
            this.mapChallenge.terminate();
        }

        this.mapChallenge = ChallengeData(active_map_uuid, challenge_id);
        this.rp_pos_arr.RemoveRange(0, this.rp_pos_arr.Length);
        this.rp_size_arr.RemoveRange(0, this.rp_size_arr.Length);
        this.rp_size_offset_arr.RemoveRange(0, this.rp_size_offset_arr.Length);
        this.rp_color_arr.RemoveRange(0, this.rp_color_arr.Length);
        this.rp_fill_color_arr.RemoveRange(0, this.rp_fill_color_arr.Length);
        this.rp_point_selected_arr.RemoveRange(0, this.rp_point_selected_arr.Length);
        this.dataPointsToDecay.RemoveRange(0, this.dataPointsToDecay.Length);
        this.dataPointsToPrint.RemoveRange(0, this.dataPointsToPrint.Length);
        this.histogramGroupArray.RemoveRange(0, this.histogramGroupArray.Length);
        this.waitForUpdateAndReload();
    }

    void waitForUpdateAndReload() {
        print("Waiting for mapChallenge.updateComplete;");
        while (!this.mapChallenge.updateComplete) {
            yield();
        }
        this.reloadHistogramData();
        this.reloadHistogramRender();
        start_size_offset = size_offset;
    }

    int getCutOffTimeAtDiv(int target_time, int precision) {
        for (uint i = 0; i < this.mapChallenge.divs.Length; i++) {
            if (Math::Abs(this.mapChallenge.divs[i].max_time - target_time) < precision) {
                return Math::Max(this.mapChallenge.divs[i].max_time, target_time);

            }
        }
        return target_time;
    }

    void handleWindowResize() {
        if (curClickLocEnum == CLICK_LOCATION::NOEDGE) {
            return;
        }
        
        vec2 mouse_pos = UI::GetMousePos();
        int mpx = int(mouse_pos.x);
        int mpy = int(mouse_pos.y);
        if (curClickLocEnum == CLICK_LOCATION::TLC ) {
            graph_x_offset = mpx;
            graph_y_offset = mpy;
            return;
        }

        if (curClickLocEnum == CLICK_LOCATION::LEFTEDGE) {
            graph_x_offset = mpx;
        }

        if (curClickLocEnum == CLICK_LOCATION::TOPEDGE) {
            graph_y_offset = mpy;
        }

        if (curClickLocEnum == CLICK_LOCATION::RIGHTEDGE || curClickLocEnum == CLICK_LOCATION::TRC || curClickLocEnum == CLICK_LOCATION::BRC) {
            graph_width = mpx - graph_x_offset;
        }

        if (curClickLocEnum == CLICK_LOCATION::BOTTOMEDGE || curClickLocEnum == CLICK_LOCATION::BLC || curClickLocEnum == CLICK_LOCATION::BRC) {
            graph_height = mpy - graph_y_offset;
        }
    }

    void addHistogramGroupsForDiv(array<HistogramGroup@>@ histogramGroupArray, int divIdx, int targetBucketSize) {
        Div@ div = @this.mapChallenge.divs[divIdx];
        int mt = div.min_time;
        int divGap = div.max_time - div.min_time;
        float numdivs = float(divGap) / float(targetBucketSize);
        float rem = numdivs % 1;
        int int_numdivs = Math::Max(int(numdivs), 1);
        int dx;
        if (rem == 0) {
            dx = targetBucketSize;
        } else {
            dx = targetBucketSize + targetBucketSize * (rem / float(int_numdivs)); 
        }
        for (int i = 0; i < int_numdivs; i++) {
            histogramGroupArray.InsertLast(HistogramGroup(mt + dx * i, mt + dx * (i + 1)));
        }
        histogramGroupArray[histogramGroupArray.Length - 1].upper = div.max_time;
    }

    int getHistBucketSizeForDiv(int divIdx, int targetSize) {
        Div@ div = this.mapChallenge.divs[divIdx];
        int divGap = div.max_time - div.min_time;
        int remainder = divGap % targetSize;
        if (remainder == 0) {
            return targetSize;
        } else {
            return targetSize + int((remainder / int(divGap / targetSize)));
        }
    }

    void reloadHistogramData() {
        if (this.reloadHistogramDataLock) {
            return;
        }
        this.reloadHistogramDataLock = true;

        if (this.mapChallenge.json_payload.Length == 0 || !this.mapChallenge.updateComplete) {
            return;
        }

        histogramGroupArray.RemoveRange(0, histogramGroupArray.Length);

        int bucket_size = calcHistBucketSize(this.mapChallenge.json_payload);

        if (this.mapChallenge.divs.IsEmpty()) {
            return;
        }
        
        for (int i = 1; i < this.mapChallenge.divs.Length; i++) {
            addHistogramGroupsForDiv(@histogramGroupArray, i, bucket_size);
        }
        uint cur_hga = 0;
        // Add actual values to each bucket
        for (uint i = 0; i < uint(Math::Min(this.mapChallenge.json_payload.Length, uint(MAX_RECORDS))); i++) {
            float time = this.mapChallenge.json_payload[i].time;
            HistogramGroup@ hg = @histogramGroupArray[cur_hga];
            if (time >= hg.lower && time <= hg.upper) {
                hg.DataPointArrays.InsertLast(@this.mapChallenge.json_payload[i]);
            } else {
                if (time < hg.lower) {
                    warn("Unexpected behavior! Report this to the dev. This error message will only confuse them, though."); 
                } else {
                    if (cur_hga != histogramGroupArray.Length - 1) {
                        cur_hga += 1;
                        i -= 1; // force it to rerun on the next one
                    }
                }
            }
            YieldByTime();
        }
        reloadValueRange();
        this.cleanPointDecay();
        this.reloadHistogramDataLock = false;
    }

    int calcHistBucketSize(array<DataPoint@>@ dpArr) {
            // Step 2: Calculate percentiles
        int totalCount = int(dpArr.Length) / 2;
        int buckets = int(totalCount / Math::Max(POINTS_PER_BUCKET, 10));

        int lowerIdx = int(totalCount * 0.25);
        int upperIdx = int(totalCount * 0.75);
        
        float lowerValue = dpArr[lowerIdx].time;
        float upperValue = dpArr[upperIdx].time;

        // Step 3: Calculate the bucket size
        float range = upperValue - lowerValue;
        int bucketSize = int(range / float(buckets));

        return bucketSize;
    }

    void reloadValueRange() {
        if (this.mapChallenge.json_payload.IsEmpty()) {
            return;
        }
        curPointRadius = POINT_RADIUS;
        valueRange = vec4(
            this.mapChallenge.json_payload[0].time - 100,
            this.mapChallenge.json_payload[int(float(Math::Min(MAX_RECORDS, this.mapChallenge.json_payload.Length)) * TARGET_DISPLAY_PERCENT)].time,
            -1,
            Math::Max(1, getMaxHistogramCount())
        );
        vr = valueRange;
        this.helpTextLocation.x = valueRange.x + (valueRange.y - valueRange.x) * 0.5 ;
        this.helpTextLocation.y = valueRange.w - (valueRange.w - valueRange.z) / 10;
        size_offset = POINT_RADIUS / (vr.w - vr.z);
        start_size_offset = size_offset;
    }
    
    int getMaxHistogramCount() {
        if (this.histogramGroupArray.IsEmpty()) {
            return 1;
        }

        int m = 0; 
        for (uint i = 0; i < histogramGroupArray.Length; i++) {
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
        for (uint i = 0; i < arr.Length; i++) {
            max_run_id = Math::Max(max_run_id, arr[i].rank);
        }
        return max_run_id; 
    }

    int getMinRank(array<DataPoint@> arr) {
        int min_run_id = 10 ** 6;
        for (uint i = 0; i < arr.Length; i++) {
            min_run_id = Math::Min(min_run_id, arr[i].rank);
        }
        return min_run_id;
    }


    vec2 TransformToViewBounds(const vec2 & in point,
        const vec2 & in min,
            const vec2 & in max) {

        auto xv = Math::InvLerp(vr.x, vr.y, point.x);
        auto yv = Math::InvLerp(vr.z, vr.w, point.y);

        return vec2(graph_x_offset + Math::Lerp(min.x, max.x, xv), graph_y_offset + Math::Lerp(min.y, max.y, yv));
    }

    bool isInViewBounds(vec2 point, vec4 bounds) {
        return point.x >= bounds.x && 
               point.x <= bounds.y && 
               point.y >= bounds.z && 
               point.y <= bounds.w;
    }

    void OnSettingsChanged() {
        startnew(CoroutineFunc(this.mapChallenge.load_external));
        startnew(CoroutineFunc(this.waitForUpdateAndReload));
    }

    void reloadHistogramRender() {
        if (this.reloadHistogramRenderLock) {
            return;
        }
        this.reloadHistogramRenderLock = true;
        vr = getValueRange();
        if (this.mapChallenge.json_payload.IsEmpty()) {
            return;
        }
        if (histogramGroupArray is null || histogramGroupArray.IsEmpty() || histogramGroupArray[0] is null) {
            return;
        }

        rp_pos_arr.RemoveRange(0, rp_pos_arr.Length);
        rp_size_arr.RemoveRange(0, rp_size_arr.Length);
        rp_size_offset_arr.RemoveRange(0, rp_size_offset_arr.Length);
        rp_color_arr.RemoveRange(0, rp_color_arr.Length);
        rp_fill_color_arr.RemoveRange(0, rp_fill_color_arr.Length);
        rp_point_selected_arr.RemoveRange(0, rp_point_selected_arr.Length);

        rpidxVal = 0;


        for (uint i = 0; i < histogramGroupArray.Length; i++) {
            HistogramGroup@ activeGroup = @histogramGroupArray[i];
            array<DataPoint@>@ activeArr = @activeGroup.DataPointArrays;
            if (activeArr is null || activeArr.Length == 0) {
                continue;
            }
            DataPoint @dp; 
            for (int j = 0; j < int(activeArr.Length); j++) {
                YieldByTime();
                @dp = @activeArr[j];
                
                float x_loc = dp.time;
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

                if (j < vr.z || j > vr.w) {
                    continue;
                }
                vec4 color = HISTOGRAM_RUN_COLOR;

                color.x += 0.05 * activeArr[j].div;
                color.y += 0.05 * activeArr[j].div ** 2;
                color.z += 0.05 * activeArr[j].div ** 3;

                color.x %= 1;
                color.y %= 1;
                color.z %= 1;

                dp.curRenderIdx = rp_pos_arr.Length;
                dp.j = j;

                rp_pos_arr.InsertLast(vec2(x_loc, y_loc));
                rp_size_arr.InsertLast(curPointRadius + dp.focus);
                rp_size_offset_arr.InsertLast(dp.focus);
                rp_color_arr.InsertLast(color);
                rp_fill_color_arr.InsertLast(vec4(0, 0, 0, 0));
                rp_point_selected_arr.InsertLast(false);
            }
        }
        this.reloadHistogramRenderLock = false;
        this.setBarHistOpacity();
    }

    void setBarHistOpacity() {
        // Basically want to determine how points are overlapping 
        // If there's at least one point of space in between each point, then render points at full brightness and bars at 0% brightness.
        // If points are touching, render points at zero brightness and bars at 100% brightness.
        // Mix it up in the middle. 

        float vr_gap = vr.w - vr.z;

        if (vr_gap == 0) {
            return;
        }

        int pixels_gap = graph_height;
        float space_per_vr_unit = pixels_gap / vr_gap;

        float min_pr = MIN_PR_MULT * POINT_RADIUS;
        float max_pr = MAX_PR_MULT * POINT_RADIUS;

        float position = Math::InvLerp(min_pr, max_pr, space_per_vr_unit);

        if (space_per_vr_unit > max_pr) {
            POINTHIST_OPACITY = 1;
            BARHIST_OPACITY = 0.1;
        } else if ( space_per_vr_unit < min_pr) {
            POINTHIST_OPACITY = 0;
            BARHIST_OPACITY = 1;
        } else {
            POINTHIST_OPACITY = position;
            BARHIST_OPACITY = Math::Max(1 - position, 0.1);
        }



    }

    void renderBarHistogram() {
        HistogramGroup@ hg; 

        float bottom_pos = -1;

        if (rp_color_arr.IsEmpty()) {
            return;
        }

        for (uint i = 0; i < histogramGroupArray.Length; i++) {
            @hg = histogramGroupArray[i];

            if (hg.DataPointArrays.IsEmpty()) {
                continue;
            }

            if (hg.DataPointArrays[0].curRenderIdx >= int(rp_color_arr.Length)) {
                // i love concurrency bugs
                continue;
            }

            if (hg.upper < vr.x || hg.lower > vr.y) {
                continue;
            }

            float lower = hg.lower; 

            if (lower < vr.x) {
                lower = vr.x;
            }

            if (hg.DataPointArrays.IsEmpty()) {
                continue;
            }

            float start_height = Math::Min(hg.DataPointArrays.Length - 0.5, vr.w);

            vec2 pos = TransformToViewBounds(vec2(lower, start_height), min, max);

            if (pos.y > graph_height + graph_y_offset) {
                continue;
            }
            float width = Math::InvLerp(0, vr.y - vr.x, hg.upper - lower);
            float height = Math::InvLerp(0, float(vr.w - vr.z), float(start_height));
            
            vec2 size = vec2(
                Math::Lerp(0, graph_width, width),
                Math::Lerp(0, graph_height, height)
            );

            vec2 br_corner = size + pos;
            br_corner.x = Math::Clamp(int(br_corner.x), graph_x_offset, graph_x_offset + graph_width);

            if (bottom_pos == -1) {
                br_corner.y = Math::Clamp(int(br_corner.y), graph_y_offset, graph_height + graph_y_offset);
                bottom_pos = br_corner.y;
            }
             else {
                br_corner.y = bottom_pos;
            }

            size = br_corner - pos;

            nvg::BeginPath();
            nvg::Rect(pos, size);
            nvg::FillColor(applyOpacityToColor(rp_color_arr[hg.DataPointArrays[0].curRenderIdx], BARHIST_OPACITY));
            nvg::Fill();
            nvg::ClosePath();
        }
    }

    void renderPbLine() {
        if (!RENDER_PB_LINE) {
            return;
        }

        if (pbTime != 0) {
            renderLine(pbTime, applyOpacityToColor(
                vec4(1),
                Math::Max(0.1, POINTHIST_OPACITY)
            ));
        }
    }

    void renderHistogram() {
        renderBarHistogram();
        renderPbLine();
        if (rp_size_arr.IsEmpty()) {
            return;
        }

        if (POINTHIST_OPACITY == 0) {
            return;
        }

        vec4 prevColor = rp_color_arr[0];

        nvg::BeginPath();
        for (uint i = 0; i < rp_pos_arr.Length; i++) {
            vec2 pos = rp_pos_arr[i];
            if (!isInViewBounds(pos, vr)) {
                continue;
            }
            pos = TransformToViewBounds(pos, min, max);
            vec4 color = (rp_fill_color_arr[i] != vec4(0) ? rp_fill_color_arr[i] : rp_color_arr[i]);
            if (color != prevColor) {
                nvg::StrokeColor(applyOpacityToColor(prevColor, POINTHIST_OPACITY));
                nvg::StrokeWidth(rp_size_arr[i]);
                nvg::Stroke();
                nvg::ClosePath();
                nvg::BeginPath();
                prevColor = color;
            }
            nvg::Circle(pos, size_offset * (rp_size_arr[i] + rp_size_offset_arr[i]));
        }
        nvg::StrokeColor(prevColor);
        nvg::StrokeWidth(rp_size_arr[rp_pos_arr.Length - 1]);
        nvg::Stroke();
        nvg::Stroke();
        nvg::ClosePath();

    }

    void renderLine(int time, vec4 color) {
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

    void renderDivs() {
        // Handles rendering the text part of divs

        for (uint i = 0; i < this.mapChallenge.divs.Length; i++) {
            Div@ div = @this.mapChallenge.divs[i];

            if (div.min_time < vr.x || div.max_time > vr.y) {
                continue;
            }

            int maxWidth = 125;
            int maxHeight = 12;
            float div_rl = Math::InvLerp(0, int(vr.y - vr.x), div.max_time - div.min_time);
            float div_pl = Math::Lerp(0, graph_width, div_rl);

            if (maxWidth <= div_pl) {
                array<string> expandedTextArr;
                expandedTextArr.InsertLast("Division " + tostring(i));
                expandedTextArr.InsertLast(Text::Format("%.3f", float(div.min_time) / 1000) + " to " + Text::Format("%.3f", float(div.max_time) / 1000));
                for (uint j = 0; j < expandedTextArr.Length; j++) {
                    vec2 textCanvasLocation = vec2(div.min_time, -1);
                    renderText(expandedTextArr[j], TransformToViewBounds(textCanvasLocation, min, max) + vec2(0, maxHeight) * j * 1.5, false);
                }

            } else {
                string minText = tostring(i);

                if (30 > div_pl) {
                    continue;
                } else {
                    vec2 textCanvasLocation = vec2(div.min_time, -1);
                    renderText(minText, TransformToViewBounds(textCanvasLocation, min, max), false);
                }
            }
        }
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
            curClickLocEnum = CLICK_LOCATION::NOEDGE;
            return;
        }

        // Check if we're clicking an edge
        CLICK_LOCATION clickLocType = getClickLocEnum(x, y);
        if (clickLocType != CLICK_LOCATION::NOEDGE) {
            curClickLocEnum = clickLocType;
            return;
        }

        if ((x > graph_x_offset - CLICK_ZONE && x < graph_x_offset + graph_width + CLICK_ZONE && y > graph_y_offset - CLICK_ZONE && y < graph_y_offset + graph_height + CLICK_ZONE)) {

            // Check if we have a point active (i.e., at 100% focus):

            DataPoint@ activePoint;
            for (uint i = 0; i < histogramGroupArray.Length; i++) {
                for (uint j = 0; j < histogramGroupArray[i].DataPointArrays.Length; j++) {
                    if (histogramGroupArray[i].DataPointArrays[j].focus == POINT_RADIUS_HOVER - 0.1) {
                        @activePoint = histogramGroupArray[i].DataPointArrays[j];
                    }
                }
            }

            if (activePoint is null) {
                // Otherwise, pan the graph
                WINDOW_MOVING = down;
                click_loc = vec2(x, y);
                if (button == 1) {
                    reloadValueRange();
                    return;
                }
            } else {
                if (activePoint.clicked) {
                    rp_fill_color_arr[activePoint.curRenderIdx] = vec4(0);
                } else {
                    rp_fill_color_arr[activePoint.curRenderIdx] = vec4(1);
                    dataPointsToPrint.InsertLast(activePoint);
                }

                if (button == 1) {
                    for (uint i = 0; i < dataPointsToPrint.Length; i++) {
                        if (dataPointsToPrint[i] is null) {
                            continue;
                        }
                        if (dataPointsToPrint[i].div == activePoint.div) {
                            removeDataPointFromDataPointsToPrint(@dataPointsToPrint[i]);
                        }
                    }
                } else {
                    activePoint.clicked = !activePoint.clicked;
                    activePoint.populateName();
                    shouldDecay = true;
                }
            }
        } else {
            // right clicking anywhere outside the graph should remove all labels
            if (button == 1) {
                for (uint i = 0; i < dataPointsToPrint.Length; i++) {
                    @dataPointsToPrint[i] = null;
                }
            }
            focused = false;
            shouldDecay = true;
        }
    }

    CLICK_LOCATION getClickLocEnum(int x, int y) {
        if (WINDOW_MOVING) {
            return CLICK_LOCATION::NOEDGE;
        }

        bool isLeftEdge = isNear(x, int(graph_x_offset - curPointRadius) + int(size_offset), CLICK_ZONE);
        bool isRightEdge = isNear(x, int(graph_x_offset + graph_width + curPointRadius + size_offset), CLICK_ZONE);
        bool isTopEdge = isNear(y, int(graph_y_offset - curPointRadius + size_offset), CLICK_ZONE);
        bool isBottomEdge = isNear(y, int(graph_y_offset + graph_height + curPointRadius + size_offset), CLICK_ZONE);

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
        if (this.mapChallenge.json_payload.Length == 0) {
            return;
        }

        vec2 mouse_pos = UI::GetMousePos();

        if (getClickLocEnum(int(mouse_pos.x), int(mouse_pos.y)) != CLICK_LOCATION::NOEDGE) {
            BorderWidth = Math::Min(BorderWidth + 0.5, CLICK_ZONE / 2);
            return;
        } else {
            BorderWidth = Math::Max(BorderWidth - 0.5, 0);
        }

        if (histogramGroupArray is null || histogramGroupArray.Length == 0) {
            return;
        }

        float mouse_hover_x = Math::Lerp(vr.x, vr.y, Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, int(mouse_pos.x)));
        float mouse_hover_y = Math::Lerp(vr.w, vr.z, Math::InvLerp(graph_y_offset, graph_y_offset + graph_height, int(mouse_pos.y - curPointRadius)));
        if (mouse_hover_y < 0) {
            return;
        }
        HistogramGroup@ histGroup;
        // find the closest datapoint to the mouse cursor

        bool matched = false;

        for (uint i = 0; !matched && i < histogramGroupArray.Length; i++) {
            if (histogramGroupArray[i] !is null && histogramGroupArray[i].lower <= mouse_hover_x && histogramGroupArray[i].upper > mouse_hover_x) {
                @histGroup = @histogramGroupArray[i];
            }
        }


        if (histGroup is null || histGroup.DataPointArrays is null || histGroup.DataPointArrays.IsEmpty()) {
            return;
        }

        if (int(mouse_hover_y) > int(histGroup.DataPointArrays.Length - 1)) {
            return;
        }

        int player_idx = int(Math::Clamp(mouse_hover_y, float(0), float(histGroup.DataPointArrays.Length - 1)));

        DataPoint@ selectedPoint;
        for (int i = player_idx; i >= 0; i--) {
            @selectedPoint = histGroup.DataPointArrays[player_idx];
        }
        if (selectedPoint is null) {
            return;
        }

        selectedPoint.increase(); 
        this.mapChallenge.divs[selectedPoint.div].increase();

        if (int(rp_size_offset_arr.Length) <= selectedPoint.curRenderIdx) {
            return;
        }

        rp_size_offset_arr[selectedPoint.curRenderIdx] = selectedPoint.focus;

        if (!rp_point_selected_arr[selectedPoint.curRenderIdx]) {
            rp_point_selected_arr[selectedPoint.curRenderIdx] = true;
            dataPointsToDecay.InsertLast(selectedPoint);
        }
        this.shouldDecay = true;
    }



    void renderDataPointText(DataPoint@ selectedPoint) {
        vec2 pos = selectedPoint.getPos();
        if (!isInViewBounds(pos, vr)) {
            return;
        }
        pos = TransformToViewBounds(pos, min, max);
        string text = "Rank: " + Text::Format("%d", selectedPoint.rank);
        text += ", Div: " + tostring(selectedPoint.div);
        text += " , Time: " + Text::Format("%.3f", float(selectedPoint.time) / 1000);

        vec2 ts = nvg::TextBounds(text);

        pos.y -= ts.y * 2.5;
        pos.x += ts.y;

        renderText(text, pos, true);

        vec2 textSize = nvg::TextBounds(text);

        pos.y += textSize.y * 1.15;

        string playerText = "Player: " + selectedPoint.name;

        renderText(playerText, pos, true);
    }

    void renderText(const string &in text, vec2 textPos, bool background) {
        vec4 c = BackdropColor;
        c.w = 0.9;
        vec2 size = nvg::TextBounds(text);

        if (!isInViewBounds(textPos + size, vec4(graph_x_offset, graph_x_offset + graph_width, graph_y_offset, graph_y_offset + graph_height))) {
            return;
        }

        if (!isInViewBounds(textPos, vec4(graph_x_offset, graph_x_offset + graph_width, graph_y_offset, graph_y_offset + graph_height))) {
            return;
        }

        if (background) {
            nvg::BeginPath();
            nvg::RoundedRect(textPos, size, BorderRadius);
            nvg::FillColor(c);
            nvg::Fill();
            nvg::ClosePath();
        }
        textPos.y += size.y;

        nvg::BeginPath();
        nvg::FillColor(vec4(.9, .9, .9, 1));
        nvg::Text(textPos, text);
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

        float xOffset = Math::InvLerp(graph_x_offset, graph_x_offset + graph_width, int(mouse_pos.x));
        float yOffset = Math::InvLerp(graph_y_offset, graph_y_offset + graph_height, int(mouse_pos.y));
        
        
        float xdiff = valueRange.y - valueRange.x;
        float ydiff = valueRange.w - valueRange.z;

        curPointRadius = curPointRadius + curPointRadius * (offset / 2);

        valueRange.x = valueRange.x + xdiff * offset * xOffset;
        valueRange.y = valueRange.y - xdiff * offset * (1 - xOffset);
        valueRange.z = valueRange.z + ydiff * offset * (1 - yOffset);
        valueRange.w = valueRange.w - ydiff * offset * yOffset;

        if (valueRange.w - valueRange.z > 0) {
            size_offset = POINT_RADIUS / (valueRange.w - valueRange.z);
        }
    }

    CSmArenaClient@ getPlayground() {
        return cast < CSmArenaClient > (GetApp().CurrentPlayground);
    }

    CSmPlayer@ getPlayer() {
        auto playground = getPlayground();
        if (playground!is null) {
            if (playground.GameTerminals.Length > 0) {
                CGameTerminal @ terminal = cast < CGameTerminal > (playground.GameTerminals[0]);
                CSmPlayer @ player = cast < CSmPlayer > (terminal.GUIPlayer);
                if (player!is null) {
                    return player;
                }   
            }
        }
        return null;
    }
    
    int getPlayerStartTime() {
        auto player = getPlayer();
        if (player !is null) {
            return player.StartTime;
        }
        return curRunStartTime;
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

vec4 applyOpacityToColor(vec4 c, float opacity) {
    c.w *= opacity;
    return c;
}