package ticketpe.runners;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class RunnerTest {

    @Test
    void ejecutarSuite() {
        Results results = Runner.path("classpath:ticketpe").parallel(5);
        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }
}
