package com.telemetry.state.controller;

import com.telemetry.state.repo.DeviceStatusReadRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/devices")
public class DeviceStatusController {

    private final DeviceStatusReadRepository repo;

    public DeviceStatusController(DeviceStatusReadRepository repo) {
        this.repo = repo;
    }

    @GetMapping("/{deviceId}/status")
    public ResponseEntity<?> getStatus(@PathVariable String deviceId) {
        return repo.getStatus(deviceId)
                .<ResponseEntity<?>>map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }
}
