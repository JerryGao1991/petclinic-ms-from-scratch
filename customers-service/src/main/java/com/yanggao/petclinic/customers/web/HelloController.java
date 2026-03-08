package com.yanggao.petclinic.customers.web;

import java.time.Instant;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import com.yanggao.petclinic.customers.config.DemoProperties;

@RestController
public class HelloController {
    private final String applicationName;
    private final  DemoProperties demoProperties;

    public HelloController(@Value("${spring.application.name:unknown}") String applicationName,
                           DemoProperties demoProperties) {
        this.applicationName = applicationName;
        this.demoProperties = demoProperties;
    }

    @GetMapping("/api/hello")
    public Map<String, Object> hello() {
        return Map.of(
                "service", applicationName,
                "message", demoProperties.getMessage(),
                "timestamp", Instant.now().toString()
        );
    }
}