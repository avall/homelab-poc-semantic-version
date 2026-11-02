package com.avall.poc.semver.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.info.BuildProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    private static final String FALLBACK_VERSION = "0.0.0-SNAPSHOT";

    @Bean
    public OpenAPI openApi(ObjectProvider<BuildProperties> buildProperties) {
        String version = buildProperties.stream().map(BuildProperties::getVersion).findFirst().orElse(FALLBACK_VERSION);
        return new OpenAPI().info(new Info().title("Hello Service").version(version));
    }
}
