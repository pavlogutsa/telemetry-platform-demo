package com.telemetry.agent.ingest.api;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.http.MediaType.APPLICATION_JSON_VALUE;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class TelemetryControllerIntegrationTest {

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanTable() {
        jdbcTemplate.update("DELETE FROM telemetry.device_status_current");
    }
    @Test
    void postTelemetry_insertsOrUpdatesRowInDb() throws Exception {
        String json = """
            {
              "deviceId": "laptop-4421",
              "cpu": 0.82,
              "mem": 0.73,
              "diskAlert": false,
              "timestamp": "2025-11-02T18:22:00Z",
              "processes": [
                {"name":"chrome.exe","cpu":0.21,"mem":0.14},
                {"name":"slack","cpu":0.05,"mem":0.07}
              ]
            }
            """;

        mockMvc.perform(post("/telemetry")
                .contentType(APPLICATION_JSON_VALUE)
                .content(json))
                .andExpect(status().isAccepted());

        Map<String, Object> row = jdbcTemplate.queryForMap(
                "SELECT cpu_pct, mem_pct, disk_alert FROM telemetry.device_status_current WHERE device_id = ?",
                "laptop-4421"
        );

        // H2 maps NUMBER(5,2) to BigDecimal, CHAR(1) to String
        assertThat(row.get("CPU_PCT")).as("CPU percentage").isNotNull();
        assertThat(row.get("MEM_PCT")).as("Mem percentage").isNotNull();
        assertThat(row.get("DISK_ALERT")).as("Disk alert flag").isEqualTo("N");
    }

    @Test
    void postTelemetry_withoutDeviceId_returnsBadRequestAndDoesNotInsert() throws Exception {
        String json = """
            {
              "cpu": 0.82,
              "mem": 0.73,
              "diskAlert": false,
              "timestamp": "2025-11-02T18:22:00Z",
              "processes": []
            }
            """;

        mockMvc.perform(post("/telemetry")
                .contentType(APPLICATION_JSON_VALUE)
                .content(json))
                .andExpect(status().isBadRequest());

        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM telemetry.device_status_current",
                Integer.class
        );

        assertThat(count).isZero();
    }
}
