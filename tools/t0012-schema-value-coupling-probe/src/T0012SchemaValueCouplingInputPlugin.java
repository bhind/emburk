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

/** Original test-only fixture for T-0012/S11 Stage A capture. */
public final class T0012SchemaValueCouplingInputPlugin implements InputPlugin {
    private static final String FIXTURE = required("T0012_COUPLING_FIXTURE");
    private static final String CAPTURE = UUID.randomUUID().toString();
    private static int sequence;
    private static boolean terminalEmitted;

    @Override
    public ConfigDiff transaction(ConfigSource config, Control control) {
        trace("transaction-entry", "1");
        try {
            Schema schema = constructSchema();
            traceSchema("transaction", schema);
            trace("control-run-entry", "1");
            try {
                control.run(Exec.newTaskSource(), schema, 1);
                trace("control-run-return", "1");
            } catch (RuntimeException failure) {
                traceException("control-run-exception", failure, "1");
                throw failure;
            }
            ConfigDiff result = Exec.newConfigDiff();
            trace("transaction-return", "1");
            terminal("success", null);
            return result;
        } catch (RuntimeException failure) {
            traceException("transaction-exception", failure, "1");
            terminal("exception", failure);
            throw failure;
        }
    }

    @Override
    public ConfigDiff resume(TaskSource taskSource, Schema schema, int taskCount, Control control) {
        trace("resume-entry", Integer.toString(taskCount));
        ConfigDiff result = Exec.newConfigDiff();
        trace("resume-return", Integer.toString(taskCount));
        return result;
    }

    @Override
    public void cleanup(TaskSource taskSource, Schema schema, int taskCount, List<TaskReport> reports) {
        trace("cleanup-entry", Integer.toString(taskCount), Integer.toString(reports.size()));
        trace("cleanup-return", Integer.toString(taskCount), Integer.toString(reports.size()));
    }

    @Override
    public TaskReport run(TaskSource taskSource, Schema schema, int taskIndex, PageOutput output) {
        String task = Integer.toString(taskIndex);
        String columns = Integer.toString(schema.getColumnCount());
        trace("run-entry", task, columns);
        traceSchema("run", schema);
        PageBuilder builder = null;
        RuntimeException primaryFailure = null;
        try {
            trace("collector-construct-entry");
            RecordingOutput collector = new RecordingOutput(schema);
            trace("collector-construct-return");
            trace("builder-construct-entry");
            builder = new PageBuilder(Exec.getBufferAllocator(), schema, collector);
            trace("builder-construct-return");
            PageBuilder active = builder;
            writeFixture(active, schema);
            operation("builder-finish", active::finish);
            operation("builder-close", active::close);
            builder = null;
            operation("runtime-output-finish", () -> output.finish());
            TaskReport report = Exec.newTaskReport();
            trace("run-return", task);
            return report;
        } catch (RuntimeException failure) {
            primaryFailure = failure;
            traceException("run-exception", failure, task, columns);
            throw failure;
        } finally {
            if (builder != null) {
                PageBuilder pending = builder;
                try {
                    operation("builder-close", pending::close);
                } catch (RuntimeException closeFailure) {
                    if (primaryFailure != null) {
                        primaryFailure.addSuppressed(closeFailure);
                    } else {
                        throw closeFailure;
                    }
                }
            }
        }
    }

    @Override
    public ConfigDiff guess(ConfigSource config) {
        trace("guess-entry");
        ConfigDiff result = Exec.newConfigDiff();
        trace("guess-return");
        return result;
    }

    private static Schema constructSchema() {
        trace("schema-construct-entry");
        try {
            Schema.Builder builder = Schema.builder();
            if ("wrong-setter".equals(FIXTURE)) {
                builder.add("number", Types.LONG);
            } else if ("duplicate-name".equals(FIXTURE)) {
                builder.add("shared", Types.LONG).add("shared", Types.STRING);
            } else {
                builder.add("flag", Types.BOOLEAN).add("number", Types.LONG)
                        .add("ratio", Types.DOUBLE).add("text", Types.STRING);
            }
            Schema schema = builder.build();
            trace("schema-construct-return");
            return schema;
        } catch (RuntimeException failure) {
            traceException("schema-construct-exception", failure);
            throw failure;
        }
    }

    private static void traceSchema(String phase, Schema schema) {
        trace("schema-fingerprint", phase, Integer.toString(schema.getColumnCount()));
        for (Column column : schema.getColumns()) {
            trace("schema-column", phase, Integer.toString(column.getIndex()),
                    column.getName(), column.getType().getName());
        }
    }

    private static void writeFixture(PageBuilder builder, Schema schema) {
        trace("input-row-count", "1");
        if ("wrong-setter".equals(FIXTURE)) {
            Column column = schema.getColumn(0);
            trace("input-cell", "0", "0", "string", "wrong");
            operation("builder-set-string", new String[] {"0", "0", "wrong"},
                    () -> builder.setString(column, "wrong"));
            addRecord(builder);
            return;
        }
        if ("duplicate-name".equals(FIXTURE)) {
            setLong(builder, schema.getColumn(0), 0, 37L);
            setString(builder, schema.getColumn(1), 0, "right");
            addRecord(builder);
            return;
        }
        if ("explicit-null".equals(FIXTURE)) {
            for (Column column : schema.getColumns()) {
                String index = Integer.toString(column.getIndex());
                trace("input-cell", "0", index, "null", null);
                operation("builder-set-null", new String[] {"0", index}, () -> builder.setNull(column));
            }
            addRecord(builder);
            return;
        }
        if (!"matching".equals(FIXTURE) && !"unset-text".equals(FIXTURE)) {
            throw new IllegalArgumentException("unknown fixture: " + FIXTURE);
        }
        setBoolean(builder, schema.getColumn(0), 0, true);
        setLong(builder, schema.getColumn(1), 0, 37L);
        setDouble(builder, schema.getColumn(2), 0, 0x8000000000000000L);
        if ("matching".equals(FIXTURE)) {
            setString(builder, schema.getColumn(3), 0, "A|B");
        } else {
            trace("input-cell-omitted", "0", "3", "string");
        }
        addRecord(builder);
    }

    private static void setBoolean(PageBuilder builder, Column column, int row, boolean value) {
        String text = Boolean.toString(value);
        trace("input-cell", Integer.toString(row), Integer.toString(column.getIndex()), "boolean", text);
        operation("builder-set-boolean", new String[] {Integer.toString(row), Integer.toString(column.getIndex()), text},
                () -> builder.setBoolean(column, value));
    }

    private static void setLong(PageBuilder builder, Column column, int row, long value) {
        String text = Long.toString(value);
        trace("input-cell", Integer.toString(row), Integer.toString(column.getIndex()), "long", text);
        operation("builder-set-long", new String[] {Integer.toString(row), Integer.toString(column.getIndex()), text},
                () -> builder.setLong(column, value));
    }

    private static void setDouble(PageBuilder builder, Column column, int row, long bits) {
        String text = String.format("%016x", bits);
        trace("input-cell", Integer.toString(row), Integer.toString(column.getIndex()), "double-bits", text);
        operation("builder-set-double", new String[] {Integer.toString(row), Integer.toString(column.getIndex()), text},
                () -> builder.setDouble(column, Double.longBitsToDouble(bits)));
    }

    private static void setString(PageBuilder builder, Column column, int row, String value) {
        trace("input-cell", Integer.toString(row), Integer.toString(column.getIndex()), "string", value);
        operation("builder-set-string", new String[] {Integer.toString(row), Integer.toString(column.getIndex()), value},
                () -> builder.setString(column, value));
    }

    private static void addRecord(PageBuilder builder) {
        operation("builder-add-record", new String[] {"0"}, builder::addRecord);
    }

    private static final class RecordingOutput implements PageOutput {
        private final Schema schema;
        private final PageReader reader;
        private int pages;
        private int rows;

        RecordingOutput(Schema schema) {
            this.schema = schema;
            trace("reader-construct-entry");
            try {
                this.reader = new PageReader(schema);
                trace("reader-construct-return");
            } catch (RuntimeException failure) {
                traceException("reader-construct-exception", failure);
                throw failure;
            }
        }

        @Override
        public void add(Page page) {
            int pageIndex = pages++;
            trace("collector-add-entry", Integer.toString(pageIndex));
            try {
                operation("reader-set-page", new String[] {Integer.toString(pageIndex)}, () -> reader.setPage(page));
                int pageRow = 0;
                while (next(pageIndex, pageRow)) {
                    readRow(pageIndex, pageRow, rows);
                    pageRow++;
                    rows++;
                }
                trace("collector-add-return", Integer.toString(pageIndex), Integer.toString(pageRow), Integer.toString(rows));
            } catch (RuntimeException failure) {
                traceException("collector-add-exception", failure, Integer.toString(pageIndex));
                throw failure;
            }
        }

        private boolean next(int page, int row) {
            trace("reader-next-record-entry", Integer.toString(page), Integer.toString(row));
            try {
                boolean result = reader.nextRecord();
                trace("reader-next-record-return", Integer.toString(page), Integer.toString(row), Boolean.toString(result));
                return result;
            } catch (RuntimeException failure) {
                traceException("reader-next-record-exception", failure, Integer.toString(page), Integer.toString(row));
                throw failure;
            }
        }

        private void readRow(int page, int pageRow, int totalRow) {
            for (Column column : schema.getColumns()) {
                String[] position = {Integer.toString(page), Integer.toString(pageRow),
                        Integer.toString(totalRow), Integer.toString(column.getIndex())};
                trace("reader-is-null-entry", position);
                boolean isNull;
                try {
                    isNull = reader.isNull(column);
                    trace("reader-is-null-return", position[0], position[1], position[2], position[3], Boolean.toString(isNull));
                } catch (RuntimeException failure) {
                    traceException("reader-is-null-exception", failure, position);
                    throw failure;
                }
                if (isNull) {
                    trace("cell-null", position);
                } else {
                    readValue(column, position);
                }
            }
        }

        private void readValue(Column column, String[] position) {
            String type = column.getType().getName();
            String event = "reader-get-" + type;
            trace(event + "-entry", position);
            try {
                String value;
                if (Types.BOOLEAN.equals(column.getType())) {
                    value = Boolean.toString(reader.getBoolean(column));
                } else if (Types.LONG.equals(column.getType())) {
                    value = Long.toString(reader.getLong(column));
                } else if (Types.DOUBLE.equals(column.getType())) {
                    value = String.format("%016x", Double.doubleToRawLongBits(reader.getDouble(column)));
                } else if (Types.STRING.equals(column.getType())) {
                    value = reader.getString(column);
                } else {
                    throw new IllegalStateException("unsupported declared type: " + type);
                }
                trace(event + "-return", position[0], position[1], position[2], position[3], value);
            } catch (RuntimeException failure) {
                traceException(event + "-exception", failure, position);
                throw failure;
            }
        }

        @Override
        public void finish() {
            trace("collector-finish-entry", Integer.toString(pages), Integer.toString(rows));
            trace("collector-finish-return", Integer.toString(pages), Integer.toString(rows));
        }

        @Override
        public void close() {
            trace("collector-close-entry", Integer.toString(pages), Integer.toString(rows));
            try {
                operation("reader-close", new String[] {Integer.toString(pages), Integer.toString(rows)}, reader::close);
                trace("collector-close-return", Integer.toString(pages), Integer.toString(rows));
            } catch (RuntimeException failure) {
                traceException("collector-close-exception", failure, Integer.toString(pages), Integer.toString(rows));
                throw failure;
            }
        }
    }

    @FunctionalInterface
    private interface Operation { void run(); }

    private static void operation(String name, Operation operation) {
        operation(name, new String[0], operation);
    }

    private static void operation(String name, String[] values, Operation operation) {
        trace(name + "-entry", values);
        try {
            operation.run();
            trace(name + "-return", values);
        } catch (RuntimeException failure) {
            traceException(name + "-exception", failure, values);
            throw failure;
        }
    }

    private static synchronized void terminal(String outcome, RuntimeException failure) {
        if (terminalEmitted) return;
        terminalEmitted = true;
        trace("terminal", outcome, failure == null ? null : failure.getClass().getName(),
                failure == null ? null : failure.getMessage());
    }

    private static void traceException(String event, RuntimeException failure, String... prefix) {
        String[] values = new String[prefix.length + 2];
        System.arraycopy(prefix, 0, values, 0, prefix.length);
        values[prefix.length] = failure.getClass().getName();
        values[prefix.length + 1] = failure.getMessage();
        trace(event, values);
    }

    private static synchronized void trace(String event, String... values) {
        StringBuilder line = new StringBuilder("COUPLINGTRACE|").append(FIXTURE).append('|')
                .append(CAPTURE).append('|').append(++sequence).append('|').append(event);
        for (String value : values) line.append('|').append(encode(value));
        System.out.println(line);
        if (System.out.checkError()) throw new EvidenceWriteError("unable to write coupling evidence");
    }

    private static String encode(String value) {
        if (value == null) return "-";
        return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
    }

    private static String required(String name) {
        String value = System.getenv(name);
        if (value == null || value.isEmpty()) throw new IllegalStateException("missing environment: " + name);
        return value;
    }

    private static final class EvidenceWriteError extends Error {
        EvidenceWriteError(String message) { super(message); }
    }
}
