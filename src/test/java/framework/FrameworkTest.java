package framework;

import io.karatelabs.core.Runner;
import io.karatelabs.core.SuiteResult;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;

/** Verifica el framework de automatización (TAS), no el SUT. Reporte aparte. */
class FrameworkTest {

    @Test
    void verificarFramework() {
        SuiteResult results = Runner.path("classpath:framework")
                .outputDir("target/karate-reports-framework")
                .backupOutputDir(false)
                .parallel(1);
        assertFalse(results.isFailed(), String.join("\n", results.getErrors()));
    }
}
