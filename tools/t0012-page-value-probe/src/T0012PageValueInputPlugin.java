import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import org.embulk.config.ConfigDiff;
import org.embulk.config.ConfigSource;
import org.embulk.config.TaskReport;
import org.embulk.config.TaskSource;
import org.embulk.spi.Column;
import org.embulk.spi.Exec;
import org.embulk.spi.InputPlugin;
import org.embulk.spi.Page;
import org.embulk.spi.PageBuilder;
import org.embulk.spi.PageOutput;
import org.embulk.spi.PageReader;
import org.embulk.spi.Schema;
import org.embulk.spi.type.Types;

/**
 * Original test-only T-0012/S07 Page value observation fixture.
 * Generated artifacts remain local-only and this is not an admitted plugin.
 */
public final class T0012PageValueInputPlugin implements InputPlugin {
    private static final String FIXTURE = requiredEnvironment("T0012_PAGE_FIXTURE");
    private static final String CAPTURE = UUID.randomUUID().toString();
    private static int sequence;
    private static boolean terminalEmitted;

    @Override
    public ConfigDiff transaction(ConfigSource config, Control control) {
        Schema schema = schema();
        trace("transaction-entry", Integer.toString(schema.getColumnCount()));
        traceSchema("transaction", schema);
        try {
            trace("control-run-entry", "1");
            control.run(Exec.newTaskSource(), schema, 1);
            trace("control-run-return", "1");
            trace("transaction-return", "1");
            terminal("success", null);
            return Exec.newConfigDiff();
        } catch (RuntimeException failure) {
            traceException("transaction-exception", failure);
            terminal("exception", failure);
            throw failure;
        }
    }

    @Override
    public ConfigDiff resume(TaskSource taskSource, Schema schema, int taskCount, Control control) {
        trace("resume-entry", Integer.toString(taskCount));
        trace("resume-return", Integer.toString(taskCount));
        return Exec.newConfigDiff();
    }

    @Override
    public void cleanup(
            TaskSource taskSource, Schema schema, int taskCount, List<TaskReport> reports) {
        trace("cleanup-entry", Integer.toString(taskCount), Integer.toString(reports.size()));
        trace("cleanup-return", Integer.toString(taskCount), Integer.toString(reports.size()));
    }

    @Override
    public TaskReport run(TaskSource taskSource, Schema schema, int taskIndex, PageOutput output) {
        trace("run-entry", Integer.toString(taskIndex), Integer.toString(schema.getColumnCount()));
        traceSchema("run", schema);
        RecordingOutput collector = new RecordingOutput(schema);
        PageBuilder builder = null;
        try {
            trace("builder-construct-entry");
            builder = new PageBuilder(Exec.getBufferAllocator(), schema, collector);
            trace("builder-construct-return");
            writeFixture(builder, schema);
            trace("builder-finish-entry");
            builder.finish();
            trace("builder-finish-return");
            trace("builder-close-entry");
            builder.close();
            trace("builder-close-return");
            builder = null;
            trace("runtime-output-finish-entry");
            output.finish();
            trace("runtime-output-finish-return");
            trace("run-return", Integer.toString(taskIndex));
            return Exec.newTaskReport();
        } catch (RuntimeException failure) {
            traceException("run-exception", failure);
            throw failure;
        } finally {
            if (builder != null) {
                // Fixture-local best-effort closure after an operation failure;
                // this does not establish a general retry or ownership policy.
                try {
                    trace("builder-close-entry");
                    builder.close();
                    trace("builder-close-return");
                } catch (RuntimeException failure) {
                    traceException("builder-close-exception", failure);
                    throw failure;
                }
            }
        }
    }

    @Override
    public ConfigDiff guess(ConfigSource config) {
        trace("guess-entry");
        trace("guess-return");
        return Exec.newConfigDiff();
    }

    private static Schema schema() {
        return Schema.builder()
                .add("flag", Types.BOOLEAN)
                .add("number", Types.LONG)
                .add("text", Types.STRING)
                .build();
    }

    private static void traceSchema(String phase, Schema schema) {
        for (int index = 0; index < schema.getColumnCount(); index++) {
            Column column = schema.getColumn(index);
            trace(
                    "schema-column",
                    phase,
                    Integer.toString(column.getIndex()),
                    column.getName(),
                    column.getType().getName());
        }
    }

    private static void writeFixture(PageBuilder builder, Schema schema) {
        if ("empty".equals(FIXTURE)) {
            trace("input-row-count", "0");
            return;
        }
        if (!"typed-null".equals(FIXTURE)) {
            throw new IllegalArgumentException("unknown fixture: " + FIXTURE);
        }
        trace("input-row-count", "3");
        writeTypedRow(builder, schema, 0, true, Long.MAX_VALUE, "");
        writeTypedRow(builder, schema, 1, false, Long.MIN_VALUE, "A|B\n\u03bb");
        writeNullRow(builder, schema, 2);
    }

    private static void writeTypedRow(
            PageBuilder builder, Schema schema, int row, boolean flag, long number, String text) {
        assignBoolean(builder, schema.getColumn(0), row, flag);
        assignLong(builder, schema.getColumn(1), row, number);
        assignString(builder, schema.getColumn(2), row, text);
        addRecord(builder, row);
    }

    private static void writeNullRow(PageBuilder builder, Schema schema, int row) {
        for (int column = 0; column < schema.getColumnCount(); column++) {
            trace("input-cell", Integer.toString(row), Integer.toString(column), "null", null);
            trace("builder-set-null-entry", Integer.toString(row), Integer.toString(column));
            builder.setNull(schema.getColumn(column));
            trace("builder-set-null-return", Integer.toString(row), Integer.toString(column));
        }
        addRecord(builder, row);
    }

    private static void assignBoolean(PageBuilder builder, Column column, int row, boolean value) {
        trace("input-cell", Integer.toString(row), "0", "boolean", Boolean.toString(value));
        trace("builder-set-boolean-entry", Integer.toString(row), "0", Boolean.toString(value));
        builder.setBoolean(column, value);
        trace("builder-set-boolean-return", Integer.toString(row), "0", Boolean.toString(value));
    }

    private static void assignLong(PageBuilder builder, Column column, int row, long value) {
        trace("input-cell", Integer.toString(row), "1", "long", Long.toString(value));
        trace("builder-set-long-entry", Integer.toString(row), "1", Long.toString(value));
        builder.setLong(column, value);
        trace("builder-set-long-return", Integer.toString(row), "1", Long.toString(value));
    }

    private static void assignString(PageBuilder builder, Column column, int row, String value) {
        trace("input-cell", Integer.toString(row), "2", "string", value);
        trace("builder-set-string-entry", Integer.toString(row), "2", value);
        builder.setString(column, value);
        trace("builder-set-string-return", Integer.toString(row), "2", value);
    }

    private static void addRecord(PageBuilder builder, int row) {
        trace("builder-add-record-entry", Integer.toString(row));
        builder.addRecord();
        trace("builder-add-record-return", Integer.toString(row));
    }

    private static final class RecordingOutput implements PageOutput {
        private final Schema schema;
        private final PageReader reader;
        private int pageOrdinal;
        private int totalRows;

        RecordingOutput(Schema schema) {
            this.schema = schema;
            trace("reader-construct-entry");
            this.reader = new PageReader(schema);
            trace("reader-construct-return");
        }

        @Override
        public void add(Page page) {
            int currentPage = pageOrdinal++;
            trace("collector-add-entry", Integer.toString(currentPage));
            try {
                trace("reader-set-page-entry", Integer.toString(currentPage));
                reader.setPage(page);
                trace("reader-set-page-return", Integer.toString(currentPage));
                int pageRow = 0;
                while (true) {
                    trace("reader-next-record-entry", Integer.toString(currentPage), Integer.toString(pageRow));
                    boolean available = reader.nextRecord();
                    trace(
                            "reader-next-record-return",
                            Integer.toString(currentPage),
                            Integer.toString(pageRow),
                            Boolean.toString(available));
                    if (!available) {
                        break;
                    }
                    readRow(currentPage, pageRow, totalRows);
                    pageRow++;
                    totalRows++;
                }
                trace(
                        "collector-add-return",
                        Integer.toString(currentPage),
                        Integer.toString(pageRow),
                        Integer.toString(totalRows));
            } catch (RuntimeException failure) {
                traceException("collector-add-exception", failure, Integer.toString(currentPage));
                throw failure;
            }
        }

        private void readRow(int page, int pageRow, int totalRow) {
            for (int column = 0; column < schema.getColumnCount(); column++) {
                Column selected = schema.getColumn(column);
                String[] position = {
                    Integer.toString(page),
                    Integer.toString(pageRow),
                    Integer.toString(totalRow),
                    Integer.toString(column)
                };
                trace("reader-is-null-entry", position);
                boolean isNull = reader.isNull(selected);
                trace(
                        "reader-is-null-return",
                        position[0], position[1], position[2], position[3], Boolean.toString(isNull));
                if (isNull) {
                    trace("cell-null", position);
                } else if (column == 0) {
                    trace("reader-get-boolean-entry", position);
                    boolean value = reader.getBoolean(selected);
                    trace(
                            "reader-get-boolean-return",
                            position[0], position[1], position[2], position[3], Boolean.toString(value));
                } else if (column == 1) {
                    trace("reader-get-long-entry", position);
                    long value = reader.getLong(selected);
                    trace(
                            "reader-get-long-return",
                            position[0], position[1], position[2], position[3], Long.toString(value));
                } else {
                    trace("reader-get-string-entry", position);
                    String value = reader.getString(selected);
                    trace("reader-get-string-return", position[0], position[1], position[2], position[3], value);
                }
            }
        }

        @Override
        public void finish() {
            trace("collector-finish-entry", Integer.toString(pageOrdinal), Integer.toString(totalRows));
            trace("collector-finish-return", Integer.toString(pageOrdinal), Integer.toString(totalRows));
        }

        @Override
        public void close() {
            trace("collector-close-entry", Integer.toString(pageOrdinal), Integer.toString(totalRows));
            try {
                trace("reader-close-entry", Integer.toString(pageOrdinal), Integer.toString(totalRows));
                reader.close();
                trace("reader-close-return", Integer.toString(pageOrdinal), Integer.toString(totalRows));
                trace("collector-close-return", Integer.toString(pageOrdinal), Integer.toString(totalRows));
            } catch (RuntimeException failure) {
                traceException("reader-close-exception", failure);
                traceException("collector-close-exception", failure);
                throw failure;
            }
        }
    }

    private static synchronized void terminal(String outcome, RuntimeException failure) {
        if (terminalEmitted) {
            return;
        }
        terminalEmitted = true;
        if (failure == null) {
            trace("terminal", outcome, null, null);
        } else {
            trace("terminal", outcome, failure.getClass().getName(), failure.getMessage());
        }
    }

    private static void traceException(String event, RuntimeException failure, String... prefix) {
        String[] values = new String[prefix.length + 2];
        System.arraycopy(prefix, 0, values, 0, prefix.length);
        values[prefix.length] = failure.getClass().getName();
        values[prefix.length + 1] = failure.getMessage();
        trace(event, values);
    }

    private static synchronized void trace(String event, String... values) {
        StringBuilder row = new StringBuilder("PAGETRACE|")
                .append(FIXTURE).append('|')
                .append(CAPTURE).append('|')
                .append(++sequence).append('|')
                .append(event);
        for (String value : values) {
            row.append('|').append(encode(value));
        }
        System.out.println(row);
        if (System.out.checkError()) {
            throw new EvidenceWriteError("unable to write Page observation evidence");
        }
    }

    private static String encode(String value) {
        if (value == null) {
            return "-";
        }
        return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
    }

    private static String requiredEnvironment(String name) {
        String value = System.getenv(name);
        if (value == null || value.isEmpty()) {
            throw new IllegalStateException("missing environment: " + name);
        }
        return value;
    }

    private static final class EvidenceWriteError extends Error {
        EvidenceWriteError(String message) {
            super(message);
        }
    }
}
