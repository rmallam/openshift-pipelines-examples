package com.example.camel;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
class GreetingRouteTest {

    @Test
    void helloEndpointReturnsGreeting() {
        given()
            .when().get("/api/hello")
            .then()
            .statusCode(200)
            .body("message", is("Hello from sample-camel"));
    }
}
