package ticketpe.runners;

import io.karatelabs.core.Runner;
import io.karatelabs.core.SuiteResult;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;

class RunnerTest {

    @Test
    void ejecutarSuite() {
        SuiteResult results = Runner.path("classpath:ticketpe")
                .outputJunitXml(true)
                .outputCucumberJson(true)
                .outputJsonLines(true)
                .parallel(5);
        assertFalse(results.isFailed(), String.join("\n", results.getErrors()));
    }
}
