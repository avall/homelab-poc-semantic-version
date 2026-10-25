package com.avall.poc.semver;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@SpringBootTest
@AutoConfigureMockMvc
class ActuatorInfoTest {

    @Autowired
    private MockMvcTester mvc;

    @Test
    void infoExposesBuildVersionAndGitCommit() {
        assertThat(mvc.get().uri("/actuator/info"))
                .hasStatusOk()
                .bodyJson()
                .satisfies(json -> {
                    json.assertThat().extractingPath("$.build.artifact").isEqualTo("homelab-poc-semantic-version");
                    json.assertThat().extractingPath("$.build.version").asString().isNotBlank();
                    json.assertThat().extractingPath("$.git.commit.id").asString().matches("[0-9a-f]{7,40}");
                    json.assertThat().extractingPath("$.git.branch").asString().isNotBlank();
                });
    }
}
