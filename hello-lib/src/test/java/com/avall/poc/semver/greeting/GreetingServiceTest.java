package com.avall.poc.semver.greeting;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class GreetingServiceTest {

    @Test
    void greetReturnsHelloworld() {
        assertThat(new GreetingService().greet()).isEqualTo("helloworld");
    }
}
