package com.avall.poc.semver.hello;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.avall.poc.semver.greeting.GreetingService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class HelloControllerTest {

    @Mock
    private GreetingService greetingService;

    @InjectMocks
    private HelloController helloController;

    @Test
    void helloReturnsGreetingFromLibrary() {
        when(greetingService.greet()).thenReturn("hello from lib");

        assertThat(helloController.hello()).isEqualTo("hello from lib");
    }
}
