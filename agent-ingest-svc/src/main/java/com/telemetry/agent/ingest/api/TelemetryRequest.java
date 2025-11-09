package com.example.ingest.api;

import java.time.Instant;
import java.util.List;

public record TelemetryRequest(
        String deviceId,
        double cpu,
        double mem,
        Boolean diskAlert,
        Instant timestamp,
        List<ProcessSample> processes
) {
    public record ProcessSample(
            String name,
            double cpu,
            double mem
    ) {}
}
