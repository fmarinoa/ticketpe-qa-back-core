package framework;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** Verifica el framework de automatización (TAS), no el SUT. Reporte aparte. */
class FrameworkTest {

    @Test
    void verificarFramework() {
        Results results = Runner.path("classpath:framework")
                .reportDir("target/karate-reports-framework")
                .backupReportDir(false)
                .parallel(1);
        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }
}
