import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import org.embulk.config.ConfigDiff;
import org.embulk.config.ConfigSource;
import org.embulk.config.TaskReport;
import org.embulk.config.TaskSource;
import org.embulk.spi.Exec;
import org.embulk.spi.OutputPlugin;
import org.embulk.spi.Page;
import org.embulk.spi.Schema;
import org.embulk.spi.TransactionalPageOutput;

/** Local-only T-0013/S05 output commit failure observation probe. */
public final class T0013CommitFailureOutputPlugin implements OutputPlugin {
    private static final String INJECTED_MESSAGE = "t0013-output-commit-failure";
    private static final String CAPTURE_ID = UUID.randomUUID().toString();
    private static volatile int selectedCommitIndex = -1;
    private static long sequence;

    @Override
    public ConfigDiff transaction(ConfigSource config, Schema schema, int taskCount, Control control) {
        String fixture = fixture();
        String count = Integer.toString(taskCount);
        String columns = Integer.toString(schema.getColumnCount());
        trace(fixture, "transaction-entry", count, columns);
        if (taskCount <= 0) {
            throw new InstrumentationError("output task count is not positive");
        }
        selectedCommitIndex = taskCount - 1;
        trace(fixture, "commit-selection", count, Integer.toString(selectedCommitIndex));
        TaskSource outputTaskSource = Exec.newTaskSource();
        trace(fixture, "control-run-before", count, columns);
        List<TaskReport> reports = runControl(fixture, "transaction-runtime-exception", control, outputTaskSource);
        if (reports == null) {
            throw new InstrumentationError("output control returned null reports");
        }
        trace(fixture, "control-run-normal-return", count, columns, Integer.toString(reports.size()));
        ConfigDiff result = Exec.newConfigDiff();
        trace(fixture, "transaction-normal-return", count, columns, Integer.toString(reports.size()));
        return result;
    }

    @Override
    public ConfigDiff resume(TaskSource taskSource, Schema schema, int taskCount, Control control) {
        String fixture = fixture();
        String count = Integer.toString(taskCount);
        String columns = Integer.toString(schema.getColumnCount());
        trace(fixture, "resume-entry", count, columns);
        trace(fixture, "resume-control-run-before", count, columns);
        List<TaskReport> reports = runControl(fixture, "resume-runtime-exception", control, taskSource);
        if (reports == null) {
            throw new InstrumentationError("output resume control returned null reports");
        }
        trace(fixture, "resume-control-run-normal-return", count, columns, Integer.toString(reports.size()));
        ConfigDiff result = Exec.newConfigDiff();
        trace(fixture, "resume-normal-return", count, columns, Integer.toString(reports.size()));
        return result;
    }

    @Override
    public void cleanup(TaskSource taskSource, Schema schema, int taskCount, List<TaskReport> reports) {
        String fixture = fixture();
        String count = Integer.toString(taskCount);
        String columns = Integer.toString(schema.getColumnCount());
        String reportCount = Integer.toString(reports.size());
        trace(fixture, "cleanup-entry", count, columns, reportCount);
        trace(fixture, "cleanup-normal-return", count, columns, reportCount);
    }

    @Override
    public TransactionalPageOutput open(TaskSource taskSource, Schema schema, int taskIndex) {
        String fixture = fixture();
        String index = Integer.toString(taskIndex);
        String columns = Integer.toString(schema.getColumnCount());
        trace(fixture, "open-entry", index, columns);
        TransactionalPageOutput result = new ObservedPageOutput(fixture, taskIndex, schema.getColumnCount());
        trace(fixture, "open-normal-return", index, columns);
        return result;
    }

    private static List<TaskReport> runControl(
            String fixture, String exceptionEvent, Control control, TaskSource taskSource) {
        RuntimeException operationFailure = null;
        List<TaskReport> reports = null;
        try {
            reports = control.run(taskSource);
        } catch (RuntimeException failure) {
            operationFailure = failure;
        }
        if (operationFailure != null) {
            trace(fixture, exceptionEvent, operationFailure.getClass().getName(),
                    operationFailure.getMessage());
            throw operationFailure;
        }
        return reports;
    }

    private static final class ObservedPageOutput implements TransactionalPageOutput {
        private final String fixture;
        private final int taskIndex;
        private final String index;
        private final String columns;

        private ObservedPageOutput(String fixture, int taskIndex, int columnCount) {
            this.fixture = fixture;
            this.taskIndex = taskIndex;
            this.index = Integer.toString(taskIndex);
            this.columns = Integer.toString(columnCount);
        }

        @Override
        public void add(Page page) {
            trace(fixture, "add-entry", index, columns);
            trace(fixture, "add-normal-return", index, columns);
        }

        @Override
        public void finish() {
            trace(fixture, "finish-entry", index, columns);
            trace(fixture, "finish-normal-return", index, columns);
        }

        @Override
        public TaskReport commit() {
            trace(fixture, "commit-entry", index, columns);
            if ("commit-failure".equals(fixture) && taskIndex == selectedCommitIndex) {
                trace(fixture, "commit-injection-before", index, columns);
                InjectedCommitFailure failure = new InjectedCommitFailure(INJECTED_MESSAGE);
                trace(fixture, "commit-runtime-exception", index, columns,
                        failure.getClass().getName(), failure.getMessage());
                throw failure;
            }
            TaskReport result = Exec.newTaskReport();
            trace(fixture, "commit-normal-return", index, columns);
            return result;
        }

        @Override
        public void abort() {
            trace(fixture, "abort-entry", index, columns);
            trace(fixture, "abort-normal-return", index, columns);
        }

        @Override
        public void close() {
            trace(fixture, "close-entry", index, columns);
            trace(fixture, "close-normal-return", index, columns);
        }
    }

    private static String fixture() {
        return System.getenv("T0013_FIXTURE");
    }

    private static synchronized void trace(String fixture, String event, String... fields) {
        StringBuilder line = new StringBuilder("COMMITOUTTRACE|").append(fixture).append('|')
                .append(CAPTURE_ID).append('|').append(++sequence).append('|').append(event);
        for (String field : fields) {
            line.append('|').append(field == null ? "-" : Base64.getEncoder()
                    .encodeToString(field.getBytes(StandardCharsets.UTF_8)));
        }
        System.out.println(line);
        if (System.out.checkError()) {
            throw new InstrumentationError("output trace failed");
        }
    }

    /** Original exception used only by the bounded selected commit fixture. */
    public static final class InjectedCommitFailure extends RuntimeException {
        private InjectedCommitFailure(String message) {
            super(message);
        }
    }

    private static final class InstrumentationError extends Error {
        private InstrumentationError(String message) {
            super(message);
        }
    }
}
