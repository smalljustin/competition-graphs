class HistogramGroup {
    int lower;
    int upper;
    int minRank, maxRank;
    array<DataPoint@>@ DataPointArrays = array<DataPoint@>();

    HistogramGroup() {
    }

    HistogramGroup(int lower, int upper) {
        this.lower = lower;
        this.upper = upper;
        this.minRank = -1;
        this.maxRank = -1;
    }
    string toString() {
        return "HGA: lower=\t" + tostring(lower) + "\tupper=\t" + tostring(upper) + "\tlen=" + tostring(DataPointArrays.Length);
    }
}