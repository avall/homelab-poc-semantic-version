package com.avall.poc.semver.greeting;

/** Builds the greeting returned by the hello service. */
public class GreetingService {

    private static final String GREETING = "helloworld";

    public String greet() {
        return GREETING;
    }
}
