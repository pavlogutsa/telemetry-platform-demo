package com.telemetry.agent.ingest.api;

import com.telemetry.agent.ingest.repo.DeviceStatusRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/telemetry")
public class TelemetryController {

    private final DeviceStatusRepository repo;

    public TelemetryController(DeviceStatusRepository repo) {
        this.repo = repo;
    }

    @PostMapping
    public ResponseEntity<Void> postTelemetry(@RequestBody TelemetryRequest body) {
        if (body.deviceId() == null || body.deviceId().isBlank()) {
            return ResponseEntity.badRequest().build();
        }

        boolean diskAlert = body.diskAlert() != null && body.diskAlert();

        repo.upsertStatus(
                body.deviceId(),
                body.cpu(),
                body.mem(),
                diskAlert,
                body.timestamp()
        );

        return ResponseEntity.accepted().build();
    }
}
