package com.telemetry.state.controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.http.MediaType.APPLICATION_JSON_VALUE;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DeviceStatusControllerIntegrationTest {

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanTable() {
        jdbcTemplate.update("DELETE FROM telemetry.device_status_current");
    }

    @Test
    void getStatus_existingDevice_returnsStatusJson() throws Exception {
        jdbcTemplate.update("""
            INSERT INTO telemetry.device_status_current
                (device_id, cpu_pct, mem_pct, disk_alert, updated_at)
            VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
            """,
            "laptop-4421", 0.82, 0.73, "Y"
        );

        mockMvc.perform(get("/devices/{deviceId}/status", "laptop-4421")
                .accept(APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_TYPE, APPLICATION_JSON_VALUE))
                .andExpect(jsonPath("$.deviceId").value("laptop-4421"))
                .andExpect(jsonPath("$.cpuPct").value(0.82))
                .andExpect(jsonPath("$.memPct").value(0.73))
                .andExpect(jsonPath("$.diskAlert").value(true))
                .andExpect(jsonPath("$.updatedAt").exists());
    }

    @Test
    void getStatus_unknownDevice_returns404() throws Exception {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM telemetry.device_status_current",
                Integer.class
        );
        assertThat(count).isZero();

        mockMvc.perform(get("/devices/{deviceId}/status", "unknown-device"))
                .andExpect(status().isNotFound());
    }
}
