class HistogramGroup {
    float lower;
    float upper;
    int minRank, maxRank;
    array<DataPoint@>@ DataPointArrays = array<DataPoint@>();

    HistogramGroup() {
    }

    HistogramGroup(float lower, float upper) {
        this.lower = lower;
        this.upper = upper;
        this.minRank = -1;
        this.maxRank = -1;
    }
    string toString() {
        return "HGA: lower=\t" + tostring(lower) + "\tupper=\t" + tostring(upper) + "\tlen=" + tostring(DataPointArrays.Length);
    }
}