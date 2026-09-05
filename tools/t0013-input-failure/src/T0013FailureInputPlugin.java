import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import org.embulk.config.ConfigDiff;
import org.embulk.config.ConfigSource;
import org.embulk.config.TaskReport;
import org.embulk.config.TaskSource;
import org.embulk.spi.Exec;
import org.embulk.spi.InputPlugin;
import org.embulk.spi.PageOutput;
import org.embulk.spi.Schema;

/** Local-only T-0013/S03 input-run failure observation probe. */
public final class T0013FailureInputPlugin implements InputPlugin {
    private static final String INJECTED_MESSAGE = "t0013-s03-injected-run-failure";
    private static final String CAPTURE_ID = UUID.randomUUID().toString();
    private static long sequence;

    @Override
    public ConfigDiff transaction(ConfigSource config, Control control) {
        String fixture = fixture();
        int taskCount = Integer.parseInt(System.getenv("T0013_TASK_COUNT"));
        String count = Integer.toString(taskCount);
        trace(fixture, "transaction-entry", count);
        TaskSource inputTaskSource = Exec.newTaskSource();
        Schema inputSchema = Schema.builder().build();
        trace(fixture, "control-run-before", count);
        RuntimeException operationFailure = null;
        try {
            control.run(inputTaskSource, inputSchema, taskCount);
        } catch (RuntimeException failure) {
            operationFailure = failure;
        }
        if (operationFailure != null) {
            trace(fixture, "transaction-runtime-exception", operationFailure.getClass().getName(),
                    operationFailure.getMessage());
            throw operationFailure;
        }
        trace(fixture, "control-run-normal-return", count);
        ConfigDiff result = Exec.newConfigDiff();
        trace(fixture, "transaction-normal-return", count);
        return result;
    }

    @Override
    public ConfigDiff resume(TaskSource taskSource, Schema schema, int taskCount, Control control) {
        String fixture = fixture();
        String count = Integer.toString(taskCount);
        trace(fixture, "resume-entry", count);
        ConfigDiff result = Exec.newConfigDiff();
        trace(fixture, "resume-normal-return", count);
        return result;
    }

    @Override
    public void cleanup(TaskSource taskSource, Schema schema, int taskCount, List<TaskReport> reports) {
        String fixture = fixture();
        String count = Integer.toString(taskCount);
        trace(fixture, "cleanup-entry", count, Integer.toString(reports.size()));
        trace(fixture, "cleanup-normal-return", count);
    }

    @Override
    public TaskReport run(TaskSource taskSource, Schema schema, int taskIndex, PageOutput output) {
        String fixture = fixture();
        String index = Integer.toString(taskIndex);
        trace(fixture, "run-entry", index);
        if ("failure".equals(fixture)) {
            trace(fixture, "injection-before", index);
            RuntimeException injectedFailure = null;
            try {
                throw new InjectedRunFailure(INJECTED_MESSAGE);
            } catch (RuntimeException failure) {
                injectedFailure = failure;
            }
            trace(fixture, "run-runtime-exception", injectedFailure.getClass().getName(),
                    injectedFailure.getMessage());
            throw injectedFailure;
        }

        trace(fixture, "finish-before", index);
        RuntimeException operationFailure = null;
        try {
            output.finish();
        } catch (RuntimeException failure) {
            operationFailure = failure;
        }
        if (operationFailure != null) {
            trace(fixture, "run-runtime-exception", operationFailure.getClass().getName(),
                    operationFailure.getMessage());
            throw operationFailure;
        }
        trace(fixture, "finish-normal-return", index);
        TaskReport result = Exec.newTaskReport();
        trace(fixture, "run-normal-return", index);
        return result;
    }

    @Override
    public ConfigDiff guess(ConfigSource config) {
        String fixture = fixture();
        trace(fixture, "guess-entry");
        ConfigDiff result = Exec.newConfigDiff();
        trace(fixture, "guess-normal-return");
        return result;
    }

    private static String fixture() {
        return System.getenv("T0013_FIXTURE");
    }

    private static synchronized void trace(String fixture, String event, String... fields) {
        StringBuilder line = new StringBuilder("FAILTRACE|").append(fixture).append('|')
                .append(CAPTURE_ID).append('|').append(++sequence).append('|').append(event);
        for (String field : fields) {
            line.append('|').append(field == null ? "-" : Base64.getEncoder()
                    .encodeToString(field.getBytes(StandardCharsets.UTF_8)));
        }
        System.out.println(line);
        if (System.out.checkError()) {
            throw new InstrumentationError("input failure trace failed");
        }
    }

    /** Original exception used only by the bounded injected fixture. */
    public static final class InjectedRunFailure extends RuntimeException {
        private InjectedRunFailure(String message) {
            super(message);
        }
    }

    private static final class InstrumentationError extends Error {
        private InstrumentationError(String message) {
            super(message);
        }
    }
}
