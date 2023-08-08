class AllRunsScatterPlot 
{
    float padding = 0;
    int ACTIVE_NUM_CPS = 0;
    float MAX_MAP_TIME = 0;
    vec4 valueRange;
    vec2 min, max;
    string active_map_uuid = "";

    int current_run_starttime;
    int current_run_id;
    int current_cp_id;
    int current_cp_idx;
    int current_lap = 1;

    float standard_deviation = 0;
    
    bool loaded = false;

    float input_target_time = 30;

    vec4 bounding_rect(0, 0, 0, 0);

    int drawn_runs = 0;
    int all_runs = 0;
    int run_derivative = 0;
    bool run_solved = false;

    int precision;

    bool WINDOW_MOVING;
    vec2 click_loc(0, 0);

    CpLog@ fastest_run = CpLog();
    CpLog@ slowest_run = CpLog();

    array<array<CpLog>> cp_log_array(0, array<CpLog>(0));
    array<CpLog> active_run_buffer(0, CpLog());

    array<HistogramGroup> histogramGroupArray();

    array<CustomTimeTarget> custom_time_targets();

    bool RUN_IS_RESPAWN;

    AllRunsScatterPlot() {
    }

    vec4 renderTrailsColor(1, 1, 1, 1);


    void Update() {
        handleMapUpdate();
        if (getCurrentCheckpoint() == -1) {
            return;
        }
        handleRunStart();
        handleWatchCheckpoint();
    }

    float getAuthor() {
        return GetApp().RootMap.TMObjective_AuthorTime;
    }
    float getGold() {
        return GetApp().RootMap.TMObjective_GoldTime;
    }
    float getSilver() {
        return GetApp().RootMap.TMObjective_SilverTime;
    }
    float getBronze() {
        return GetApp().RootMap.TMObjective_BronzeTime;
    }
    int getNumLaps() {
        return GetApp().RootMap.TMObjective_NbLaps;
    }
    bool isMultiLap() {
        return GetApp().RootMap.TMObjective_IsLapRace;
    }
    bool isEditorOpen() {
        return false;
    }


    bool isIdxFinish(int idx) {
        return getPlayground().Arena.MapLandmarks[idx].Waypoint.IsFinish;
    }

    void OnSettingsChanged() {
        reloadValueRange();
        updateBoundingRect();
        run_derivative = 0;
        run_solved = false;
    }

    void updateBoundingRect() {
        bounding_rect = vec4(graph_x_offset, graph_x_offset + m_size.x, graph_y_offset, graph_y_offset + m_size.y);
    }

     
    int getCurrentGameTime() {
        return getPlayground().Interface.ManialinkScriptHandler.GameTime;
    }

    float GET_SLOWEST_RUN_CUTOFF() {
        if (HISTOGRAM_VIEW) {
            return SLOW_RUN_CUTOFF_HIST;
        } else {
            return SLOW_RUN_CUTOFF_SCATTER;
        }
    }

    void adjustStDevTarget() {
        if (MANUAL_OVERRIDE_SCATTER_BOUNDS || SCATTER_SHOW_ALL_RUNS || HISTOGRAM_VIEW || run_solved || (all_runs == 0) || valueRange.w == getSlowestCustomTargetTime() || OVERRIDE_SHOW_SECONDS) {
            return;
        }
        float frac = float(drawn_runs) / float(all_runs);
        if (frac < SCATTER_TARGET_PERCENT) {
            if (run_derivative == -1) {
                run_solved = true;
            }
            run_derivative = 1;
            UPPER_STDEV_MULT += 0.025;
        } else {
            if (run_derivative == 1) {
                run_solved = true;
            }
            run_derivative = -1;
            UPPER_STDEV_MULT -= .025;
        }
        reloadValueRange();
    }
    /**
     * Returns the player's starting time as an integer. 
     */
    int getPlayerStartTime() {
        return getPlayer().StartTime;
    }

    void testPlayerRespawned() {
        if (RUN_IS_RESPAWN) {
            return;
        }
        auto player = getPlayer();
        auto scriptPlayer = player is null ? null : cast<CSmScriptPlayer>(player.ScriptAPI);
        RUN_IS_RESPAWN = scriptPlayer.Score.NbRespawnsRequested > 0;
    }

    void renderCustomInputMenu() {
        if (showTimeInputWindow) {
            UI::Begin("Enter a custom time target", UI::WindowFlags::AlwaysAutoResize);
                input_target_time = UI::InputFloat("Target time", input_target_time, 0.005);
                if (UI::Button("Save", vec2(200, 30))) {
                    databasefunctions.addCustomTimeTarget(active_map_uuid, input_target_time);
                    doCustomTimeTargetRefresh();
                };
                if (UI::Button("Remove All", vec2(200, 30))) {
                    databasefunctions.removeAllCustomTimeTargets(active_map_uuid);
                    doCustomTimeTargetRefresh();
                };
                if (UI::Button("Close", vec2(200, 30))) {
                    showTimeInputWindow = false;
                };

            UI::End();
        }
    }

    void renderMouseHover() {
        if (HISTOGRAM_VIEW && shouldRenderHistStatistics()) {
            return;
        }
        vec2 mouse_pos = UI::GetMousePos();
        if (mouse_pos.x > bounding_rect.x && mouse_pos.x < bounding_rect.y && mouse_pos.y > bounding_rect.z && mouse_pos.y < bounding_rect.w) {
            string text; 

            if (HISTOGRAM_VIEW) {
                float mouse_hover_x = Math::Lerp(valueRange.x, valueRange.y, Math::InvLerp(bounding_rect.x, bounding_rect.y, mouse_pos.x));
                float mouse_hover_y = Math::Lerp(valueRange.z, valueRange.w, Math::InvLerp(bounding_rect.w, bounding_rect.z, mouse_pos.y));

                int idx = (mouse_hover_x - fastest_run.time) / precision;

                if (idx < 0 || idx >= histogramGroupArray.Length) {
                    return;
                }
                HistogramGroup @histGroup = histogramGroupArray[idx];

                if (precision == 1) {
                    text = "Time: " + Text::Format("%.3f", histGroup.lower / 1000);
                } else {
                    text = "Time: " + Text::Format("%.3f", histGroup.lower / 1000) + " to " + Text::Format("%.3f", histGroup.upper / 1000);
                }

                text += "\tRuns: " + tostring(Math::Ceil(histGroup.cpLogArrays.Length));

            } else {
                float mouse_hover_y = Math::Lerp(valueRange.z, valueRange.w, Math::InvLerp(bounding_rect.w, bounding_rect.z, mouse_pos.y));
                text = "Time: " + Text::Format("%.3f", mouse_hover_y / 1000);
            }

            nvg::BeginPath();
            // nvg::Rect(mouse_pos - vec2(0, nvg::TextBounds(text).y), nvg::TextBounds(text));
            nvg::FillColor(vec4(.9, .9, .9, 1));
            // nvg::Fill();
            nvg::Text(mouse_pos, text);
            nvg::Stroke();
            nvg::ClosePath();
        }
    }

    
    void Render(vec2 parentSize, float LineWidth) {
        if (!g_visible || isEditorOpen()) {
            return;
        }
        if (cp_log_array.Length == 0 || precision == 0 || standard_deviation == 0) {
            return;
        }
        float _padding = padding;
        min = vec2(_padding, parentSize.y - _padding);
        max = vec2(parentSize.x - _padding, _padding);


        renderHistogram();
        renderMouseHover();
        renderMedals();
        renderCustomInputMenu();
        handleWindowMoving();
    }

    void doCustomTimeTargetRefresh() {
        custom_time_targets = databasefunctions.getCustomTimeTargetsForMap(active_map_uuid);
        OnSettingsChanged();
    }


    /**
     * Saves the previous checkpoint information to the active run buffer.
     */
    void saveCheckpointInformation() {
        active_run_buffer.InsertLast(
            CpLog(active_map_uuid, current_run_id, current_cp_idx, getCurrentRunTime())
        );
    }

    int getCurrentCheckpoint() {
        auto player = getPlayer();
        if (player !is null) {
            return player.CurrentLaunchedRespawnLandmarkIndex;
        } else {
            return -1;
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

    void reloadValueRangeHistogram() {
        valueRange = vec4(fastest_run.time - 3 * precision, fastest_run.time * GET_SLOWEST_RUN_CUTOFF(), -1, getMaxHistogramCount() + 1);
    }

    float getFastestCustomTargetTime() {
        float s = 0xDEADBEEF;
        for (int i = 0; i < custom_time_targets.Length; i++) {
            s = Math::Min(s, custom_time_targets[i].target_time);
        }
        return s;
    }

    float getSlowestCustomTargetTime() {
        float s = 0;
        for (int i = 0; i < custom_time_targets.Length; i++) {
            s = Math::Max(s, custom_time_targets[i].target_time);
        }
        return s;
    }

    void reloadValueRangeScatter() {
        int max_run_id = 0;
        int min_run_id = 10 ** 5;

        for (int i = 0; i < cp_log_array.Length; i++) {
            min_run_id = Math::Min(min_run_id, cp_log_array[i][0].run_id);
            max_run_id = Math::Max(max_run_id, cp_log_array[i][0].run_id);
        }
        min_run_id = Math::Max(min_run_id, max_run_id - NUM_SCATTER_PAST_GHOSTS);

        float fastest_time = INCLUDE_FASTEST_CUSTOM_TARGET_TIME ? Math::Min(getFastestCustomTargetTime(), fastest_run.time) : fastest_run.time;

        valueRange = vec4(min_run_id - 1, max_run_id + 1, fastest_time - LOWER_STDEV_MULT * standard_deviation, fastest_run.time + standard_deviation * UPPER_STDEV_MULT);

        if (INCLUDE_SLOWEST_CUSTOM_TARGET_TIME) {
            valueRange.w = Math::Max(valueRange.w, getSlowestCustomTargetTime());
        }

        if (SCATTER_SHOW_ALL_RUNS) {
            valueRange.w = slowest_run.time * 1.1;
        }

        if (OVERRIDE_SHOW_SECONDS) {
            if (fastest_run != null) {
                valueRange.w = fastest_run.time + OVERRIDE_SECONDS_ABOVE_PB_SHOW * 1000;
                valueRange.z = fastest_run.time - OVERRIDE_SECONDS_BELOW_PB_SHOW * 1000;
            }
        }
    }

    void renderMedals() {
        if (DRAW_AUTHOR) {
            renderMedal(getAuthor(), AUTHOR_COLOR);
        }
        if (DRAW_GOLD) {
            renderMedal(getGold(), GOLD_COLOR);
        }
        if (DRAW_SILVER) {
            renderMedal(getSilver(), SILVER_COLOR);
        }
        if (DRAW_BRONZE) {
            renderMedal(getBronze(), BRONZE_COLOR);
        }

        for (int i = 0; i < custom_time_targets.Length; i++) {
            renderMedal(custom_time_targets[i].target_time, CUSTOM_TARGET_COLOR);
        }
    }

    void renderMedal(float time, vec4 color) {
        if (HISTOGRAM_VIEW && SHOW_MEDALS_IN_HISTOGRAM) {
            if (time >= valueRange.x && time <= valueRange.y) {
                nvg::BeginPath();
                nvg::MoveTo(TransformToViewBounds(ClampVec2(vec2(time, valueRange.z), valueRange), min, max));
                nvg::LineTo(TransformToViewBounds(ClampVec2(vec2(time, valueRange.w), valueRange), min, max));
                nvg::StrokeColor(color);
                nvg::StrokeWidth(LineWidth);
                nvg::Stroke();
                nvg::ClosePath();
            }
        } else {
                    if (time >= valueRange.z && time <= valueRange.w) {
                nvg::BeginPath();
                nvg::MoveTo(TransformToViewBounds(ClampVec2(vec2(valueRange.x, time), valueRange), min, max));
                nvg::LineTo(TransformToViewBounds(ClampVec2(vec2(valueRange.y, time), valueRange), min, max));
                nvg::StrokeColor(color);
                nvg::StrokeWidth(LineWidth);
                nvg::Stroke();
                nvg::ClosePath();
            }
        }


    }
    void handleMapUpdate() {
        string map_uuid = getMapUid();
        if (map_uuid == "" || map_uuid == active_map_uuid) {
            return;
        }
        doCustomTimeTargetRefresh();
        input_target_time = getAuthor() / 1000;
    }

    vec2 ClampVec2(const vec2 & in val,
        const vec4 & in bounds) {
        return vec2(Math::Clamp(val.x, bounds.x, bounds.y), Math::Clamp(val.y, bounds.z, bounds.w));
    }

    vec2 TransformToViewBounds(const vec2 & in point,
        const vec2 & in min,
            const vec2 & in max) {
        auto xv = Math::InvLerp(valueRange.x, valueRange.y, point.x);
        auto yv = Math::InvLerp(valueRange.z, valueRange.w, point.y);
        return vec2(graph_x_offset + Math::Lerp(min.x, max.x, xv), graph_y_offset + Math::Lerp(min.y, max.y, yv));
    }

    void updateHistogramGroups() {
        if (cp_log_array.Length == 0) {
            return;
        }
        precision = HIST_PRECISION_VALUE * 1000;
        histogramGroupArray = array<HistogramGroup>();
        for (int i = fastest_run.time; i < fastest_run.time * GET_SLOWEST_RUN_CUTOFF(); i += precision) {
            histogramGroupArray.InsertLast(HistogramGroup(i, i + precision));
        }

        int end_pos = cp_log_array.Length - HIST_RUN_START_OFFSET;
        int start_pos = Math::Max(0, end_pos - HIST_RUNS_TO_SHOW);
        
        for (int i = start_pos; i < end_pos; i++) {
            float time = cp_log_array[i][cp_log_array[i].Length - 1].time;
            int idx = (time - fastest_run.time) / precision;
            if (idx >= histogramGroupArray.Length) {
                continue;
            }
            histogramGroupArray[idx].cpLogArrays.InsertLast(cp_log_array[i]);
        }
    }

    int getMaxHistogramCount() {
        float m = 0; 
        for (int i = 0; i < histogramGroupArray.Length; i++) {
            m = Math::Max(histogramGroupArray[i].cpLogArrays.Length, m);
        }
        return m;
    }

    int getMaxRunId(HistogramGroup @histogramGroup) {
        if (histogramGroup.maxRunId != -1) {
            return histogramGroup.maxRunId;
        } else {
            histogramGroup.maxRunId = getMaxRunId(histogramGroup.cpLogArrays);
            return histogramGroup.maxRunId;
        }
    }

    int getMinRunId(HistogramGroup @histogramGroup) {
        if (histogramGroup.minRunId != -1) {
            return histogramGroup.minRunId; 
        } else {
            histogramGroup.minRunId = getMinRunId(histogramGroup.cpLogArrays);
            return histogramGroup.minRunId; 
        }
    }

    int getMaxRunId(array<array<CpLog>@>@ cp_log_array) {
        int max_run_id = -1;
        for (int i = 0; i < cp_log_array.Length; i++) {
            max_run_id = Math::Max(max_run_id, cp_log_array[i][0].run_id);
        }

        return max_run_id; 
    }

    int getMinRunId(array<array<CpLog>@>@ cp_log_array) {
        int min_run_id = 10 ** 6;
        for (int i = 0; i < cp_log_array.Length; i++) {
            min_run_id = Math::Min(min_run_id, cp_log_array[i][0].run_id);
        }
        return min_run_id;
    }

    void renderHistogram() {
        for (int i = 0; i < histogramGroupArray.Length; i++) {
            for (int j = 0; j < histogramGroupArray[i].cpLogArrays.Length; j++) {
                array<CpLog>@ activeArr = histogramGroupArray[i].cpLogArrays[j];
                float x_loc = activeArr[activeArr.Length - 1].time;
                float y_loc = Math::Lerp(0, histogramGroupArray[i].cpLogArrays.Length, 
                    Math::InvLerp(
                        getMinRunId(@histogramGroupArray[i]),
                        getMaxRunId(@histogramGroupArray[i]
                    ),
                    activeArr[0].run_id));

                if (histogramGroupArray[i].cpLogArrays.Length == 1) {
                    y_loc = 0;
                }
                
                vec4 color = HISTOGRAM_RUN_COLOR * Math::InvLerp(0, current_run_id, activeArr[0].run_id) ** 0.5;

                if (x_loc == fastest_run.time) {
                    color = HISTOGRAM_PB_COLOR;
                }
                

                nvg::BeginPath();
                nvg::Circle(
                TransformToViewBounds(ClampVec2(vec2(x_loc, y_loc), valueRange), min, max),
                POINT_RADIUS
                );
                nvg::StrokeColor(color);
                nvg::StrokeWidth(POINT_RADIUS ** 2);
                nvg::Stroke();
                nvg::ClosePath();
            }
        }
    }

    void handleWindowMoving() {
        if (!WINDOW_MOVING) {
            return;
        }
        vec2 pos = UI::GetMousePos();
        graph_x_offset = pos.x - click_loc.x;
        graph_y_offset = pos.y - click_loc.y;
        updateBoundingRect();
    }

    void OnMouseButton(bool down, int button, int x, int y) {
        if (x > bounding_rect.x && x < bounding_rect.y && y > bounding_rect.z && y < bounding_rect.w) {
            WINDOW_MOVING = down;
            click_loc = vec2(x - graph_x_offset, y - graph_y_offset);
        }
    }
}

