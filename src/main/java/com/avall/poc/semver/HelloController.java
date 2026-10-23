package com.avall.poc.semver;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class HelloController {

    @GetMapping(value = "/hello", produces = MediaType.TEXT_PLAIN_VALUE)
    String hello() {
        return "helloworld";
    }
}
