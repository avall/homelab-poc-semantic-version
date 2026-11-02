package com.avall.poc.semver.config;

import com.avall.poc.semver.greeting.GreetingService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Registers the plain hello-lib service as a Spring bean. */
@Configuration
public class GreetingConfig {

    @Bean
    public GreetingService greetingService() {
        return new GreetingService();
    }
}
