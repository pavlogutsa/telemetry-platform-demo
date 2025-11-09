package com.example.ingest.api;

import com.example.ingest.repo.DeviceStatusRepository;
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

        repo.upsertStatus(
                body.deviceId(),
                body.cpu(),
                body.mem(),
                body.diskAlert() != null && body.diskAlert(),
                body.timestamp()
        );

        return ResponseEntity.accepted().build();
    }
}
