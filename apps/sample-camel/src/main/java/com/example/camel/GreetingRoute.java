package com.example.camel;

import jakarta.enterprise.context.ApplicationScoped;
import org.apache.camel.builder.RouteBuilder;

@ApplicationScoped
public class GreetingRoute extends RouteBuilder {

    @Override
    public void configure() {
        rest("/api")
            .get("/hello")
            .produces("application/json")
            .to("direct:hello");

        from("direct:hello")
            .setBody(constant("{\"message\":\"Hello from sample-camel\"}"));
    }
}
