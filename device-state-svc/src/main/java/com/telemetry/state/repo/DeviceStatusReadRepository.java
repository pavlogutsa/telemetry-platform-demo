package com.telemetry.state.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public class DeviceStatusReadRepository {

    private final JdbcTemplate jdbc;        

    public DeviceStatusReadRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<DeviceStatus> getStatus(String deviceId) {
        return jdbc.query("""
            SELECT device_id, cpu_pct, mem_pct, disk_alert, updated_at
            FROM telemetry.device_status_current
            WHERE device_id = ?
        """,
        rs -> {
            if (!rs.next()) return Optional.empty();
            return Optional.of(new DeviceStatus(
                    rs.getString("device_id"),
                    rs.getDouble("cpu_pct"),
                    rs.getDouble("mem_pct"),
                    "Y".equals(rs.getString("disk_alert")),
                    rs.getTimestamp("updated_at").toInstant()
            ));
        }, deviceId);
    }

    public record DeviceStatus(
            String deviceId,
            double cpuPct,
            double memPct,
            boolean diskAlert,
            java.time.Instant updatedAt
    ) {}
}
