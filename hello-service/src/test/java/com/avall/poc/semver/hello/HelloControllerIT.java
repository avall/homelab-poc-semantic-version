package com.avall.poc.semver.hello;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.web.client.RestClient;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class HelloControllerIT {

    @LocalServerPort
    private int localServerPort;

    private RestClient restClient;

    @BeforeEach
    void init() {
        restClient = RestClient.builder().baseUrl("http://localhost:" + localServerPort).build();
    }

    @Test
    void whenGetHelloThenReturnsHelloworld() {
        assertThat(restClient.get().uri("/hello").retrieve().body(String.class)).isEqualTo("helloworld");
    }

    @Test
    void whenGetApiDocsThenExposesServiceTitle() {
        var apiDocs = restClient.get().uri("/v3/api-docs").retrieve().body(ApiDocs.class);

        assertThat(apiDocs).isNotNull();
        assertThat(apiDocs.info().title()).isEqualTo("Hello Service");
    }

    private record ApiDocs(Info info) {}

    private record Info(String title) {}
}
