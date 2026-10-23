package com.avall.poc.semver;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@WebMvcTest(HelloController.class)
class HelloControllerTest {

    @Autowired
    private MockMvcTester mvc;

    @Test
    void helloReturnsPlainTextHelloworld() {
        assertThat(mvc.get().uri("/hello"))
                .hasStatusOk()
                .hasContentTypeCompatibleWith(MediaType.TEXT_PLAIN)
                .hasBodyTextEqualTo("helloworld big change");
    }
}
