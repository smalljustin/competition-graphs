int DEFAULT = 1; 

float getAverage(array<float> values) {
    if (values.Length == 0) {
        return 0;
    }
    float sum = 0;
    float min = getMin(values);
    int count = 0;
    for (int i = 0; i < values.Length; i++) {
        if (values[i] < SLOW_RUN_CUTOFF_SCATTER * min) {
            sum += values[i];
            count += 1;
        }
    }

    if (count == 0) {
        return 0;
    }
    return sum / count;
}

float getMin(array<float> values) {
    if (values.Length == 0) {
        return 0;
    }
    float min = values[0];
    for (int i = 1; i < values.Length; i++) {
        if (values[i] < min) {
            min = values[i];
        }
    }
    return min;
}

float __getStandardDeviation(array<float> @values) {
    if (values.Length == 0) {
        // idk bro this will make rendering math easier
        return DEFAULT;
    }

    float avg = getAverage(values);
    float min = getMin(values);
    float rollingVariance = 0;
    int count = 0;

    for (int i = 0; i < values.Length; i++) {
        if (values[i] < SLOW_RUN_CUTOFF_SCATTER * min) {
            rollingVariance += (values[i] - avg) ** 2;
            count += 1;
        }
    }
    if (count == 0) {
        return DEFAULT;
    }
    rollingVariance /= count;
    return rollingVariance ** 0.5;
}

float _getStandardDeviation(array<array<DataPoint>> @DataPointArrayArray) {
    if (DataPointArrayArray.Length == 0) {
        return DEFAULT;
    }
    array<float> runTimes();
    for (int i = 0; i < DataPointArrayArray.Length; i++) {
        runTimes.InsertLast(DataPointArrayArray[i][DataPointArrayArray[i].Length - 1].time);
    }
    return __getStandardDeviation(runTimes);
}

float getStandardDeviation(array<array<DataPoint>> @DataPointArrayArray, int numLast) {
    // Gets the standard deviation of the last n elements.
    numLast = Math::Min(DataPointArrayArray.Length, numLast);
    array<array<DataPoint>> runsForStandardDeviation(); 
    for (int i = 0; i < numLast; i++) {
        runsForStandardDeviation.InsertLast(DataPointArrayArray[i]);
    }
    return _getStandardDeviation(runsForStandardDeviation);
}
