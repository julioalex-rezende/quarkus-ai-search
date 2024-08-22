package neutrino;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
class GreetingResourceTest {
    @Test
    void testHelloEndpoint() {
        given()
          .when().get("/hello")
          .then()
             .statusCode(200)
             .body(is("Hello from RESTEasy\n"));
    }

    @Test
    void testHelloUserEndpoint() {
        String inputText = "John";
        given()
          .body(inputText)
          .header("Content-Type", "text/plain")
          .when().post("/hello/user")
          .then()
             .statusCode(200)
             .body(is("Hello from RESTEasy, " + inputText + "\n"));
    }

}