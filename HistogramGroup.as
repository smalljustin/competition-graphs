class HistogramGroup {
    float lower;
    float upper;
    int minRunId, maxRunId;
    array<array<CpLog>@> cpLogArrays;

    HistogramGroup() {}

    HistogramGroup(float lower, float upper) {
        this.lower = lower;
        this.upper = upper;
        this.minRunId = -1;
        this.maxRunId = -1;
    }
    string toString() {
        return "HGA: lower=\t" + tostring(lower) + "\tupper=\t" + tostring(upper) + "\tlen=" + tostring(cpLogArrays.Length);
    }
}