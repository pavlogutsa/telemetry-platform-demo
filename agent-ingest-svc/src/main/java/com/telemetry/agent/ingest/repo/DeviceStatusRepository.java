package com.example.ingest.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.Instant;

@Repository
public class DeviceStatusRepository {
    private final JdbcTemplate jdbc;

    public DeviceStatusRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void upsertStatus(String deviceId,
                             double cpuPct,
                             double memPct,
                             boolean diskAlert,
                             Instant ts) {

        int updated = jdbc.update("""
            UPDATE telemetry.device_status_current
               SET cpu_pct = ?, mem_pct = ?, disk_alert = ?, updated_at = SYSTIMESTAMP
             WHERE device_id = ?
        """, cpuPct, memPct, diskAlert ? "Y" : "N", deviceId);

        if (updated == 0) {
            jdbc.update("""
                INSERT INTO telemetry.device_status_current
                    (device_id, cpu_pct, mem_pct, disk_alert, updated_at)
                VALUES (?, ?, ?, ?, SYSTIMESTAMP)
            """, deviceId, cpuPct, memPct, diskAlert ? "Y" : "N");
        }
    }
}
