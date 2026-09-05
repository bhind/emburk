import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;

import org.embulk.config.ConfigDiff;
import org.embulk.config.ConfigSource;
import org.embulk.config.TaskReport;
import org.embulk.config.TaskSource;
import org.embulk.spi.Exec;
import org.embulk.spi.InputPlugin;
import org.embulk.spi.PageOutput;
import org.embulk.spi.Schema;

/** Local-only T-0013/S01 lifecycle observation probe. */
public final class T0013InputPlugin implements InputPlugin {
    private static long sequence;

    @Override
    public ConfigDiff transaction(ConfigSource config, Control control) {
        String fixture = System.getenv("T0013_FIXTURE");
        int count = Integer.parseInt(System.getenv("T0013_TASK_COUNT"));
        trace(fixture, "transaction-entry", Integer.toString(count));
        TaskSource inputTaskSource = Exec.newTaskSource();
        Schema inputSchema = Schema.builder().build();
        trace(fixture, "control-run-before", Integer.toString(count));
        RuntimeException operationFailure = null;
        try {
            control.run(inputTaskSource, inputSchema, count);
        } catch (RuntimeException failure) {
            operationFailure = failure;
        }
        if (operationFailure != null) {
            trace(fixture, "transaction-runtime-exception", operationFailure.getClass().getName(),
                    operationFailure.getMessage());
            throw operationFailure;
        }
        trace(fixture, "control-run-normal-return", Integer.toString(count));
        ConfigDiff result = Exec.newConfigDiff();
        trace(fixture, "transaction-normal-return", Integer.toString(count));
        return result;
    }

    @Override
    public ConfigDiff resume(TaskSource taskSource, Schema schema, int taskCount, Control control) {
        String fixture = System.getenv("T0013_FIXTURE");
        trace(fixture, "resume-entry", Integer.toString(taskCount));
        ConfigDiff result = Exec.newConfigDiff();
        trace(fixture, "resume-normal-return", Integer.toString(taskCount));
        return result;
    }

    @Override
    public void cleanup(TaskSource taskSource, Schema schema, int taskCount, List<TaskReport> reports) {
        String fixture = System.getenv("T0013_FIXTURE");
        trace(fixture, "cleanup-entry", Integer.toString(taskCount), Integer.toString(reports.size()));
        trace(fixture, "cleanup-normal-return", Integer.toString(taskCount));
    }

    @Override
    public TaskReport run(TaskSource taskSource, Schema schema, int taskIndex, PageOutput output) {
        String fixture = System.getenv("T0013_FIXTURE");
        trace(fixture, "run-entry", Integer.toString(taskIndex));
        trace(fixture, "finish-before", Integer.toString(taskIndex));
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
        trace(fixture, "finish-normal-return", Integer.toString(taskIndex));
        TaskReport result = Exec.newTaskReport();
        trace(fixture, "run-normal-return", Integer.toString(taskIndex));
        return result;
    }

    @Override
    public ConfigDiff guess(ConfigSource config) {
        String fixture = System.getenv("T0013_FIXTURE");
        trace(fixture, "guess-entry");
        ConfigDiff result = Exec.newConfigDiff();
        trace(fixture, "guess-normal-return");
        return result;
    }

    private static synchronized void trace(String fixture, String event, String... fields) {
        StringBuilder line = new StringBuilder("TRACE|").append(fixture).append('|')
                .append(++sequence).append('|').append(event);
        for (String field : fields) {
            line.append('|').append(field == null ? "-" : Base64.getEncoder()
                    .encodeToString(field.getBytes(StandardCharsets.UTF_8)));
        }
        System.out.println(line);
        if (System.out.checkError()) {
            throw new InstrumentationError("trace output failed");
        }
    }

    private static final class InstrumentationError extends Error {
        private InstrumentationError(String message) {
            super(message);
        }
    }
}
