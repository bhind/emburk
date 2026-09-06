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

/** Test-only original fixture for the bounded T-0012/S09 observation. */
public final class T0012DoubleValueInputPlugin implements InputPlugin {
    private static final String FIXTURE = requiredEnvironment("T0012_DOUBLE_FIXTURE");
    private static final String CAPTURE = UUID.randomUUID().toString();
    private static int sequence;
    private static boolean terminalEmitted;

    @Override
    public ConfigDiff transaction(ConfigSource config, Control control) {
        trace("transaction-entry", "1");
        try {
            Schema schema = recordSchemaConstruction();
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
        try {
            ConfigDiff result = Exec.newConfigDiff();
            trace("resume-return", Integer.toString(taskCount));
            return result;
        } catch (RuntimeException failure) {
            traceException("resume-exception", failure, Integer.toString(taskCount));
            throw failure;
        }
    }

    @Override
    public void cleanup(TaskSource taskSource, Schema schema, int taskCount, List<TaskReport> reports) {
        trace("cleanup-entry", Integer.toString(taskCount), Integer.toString(reports.size()));
        try {
            trace("cleanup-return", Integer.toString(taskCount), Integer.toString(reports.size()));
        } catch (RuntimeException failure) {
            traceException("cleanup-exception", failure, Integer.toString(taskCount), Integer.toString(reports.size()));
            throw failure;
        }
    }

    @Override
    public TaskReport run(TaskSource taskSource, Schema schema, int taskIndex, PageOutput output) {
        String task = Integer.toString(taskIndex);
        String columnCount = Integer.toString(schema.getColumnCount());
        trace("run-entry", task, columnCount);
        traceSchema("run", schema);
        RecordingOutput collector;
        PageBuilder builder = null;
        try {
            trace("collector-construct-entry");
            try {
                collector = new RecordingOutput(schema);
                trace("collector-construct-return");
            } catch (RuntimeException failure) {
                traceException("collector-construct-exception", failure);
                throw failure;
            }
            trace("builder-construct-entry");
            try {
                builder = new PageBuilder(Exec.getBufferAllocator(), schema, collector);
                trace("builder-construct-return");
            } catch (RuntimeException failure) {
                traceException("builder-construct-exception", failure);
                throw failure;
            }
            final PageBuilder activeBuilder = builder;
            writeFixture(activeBuilder, schema.getColumn(0));
            recordOperation("builder-finish", () -> activeBuilder.finish());
            recordOperation("builder-close", () -> activeBuilder.close());
            builder = null;
            recordOperation("runtime-output-finish", () -> output.finish());
            TaskReport result = Exec.newTaskReport();
            trace("run-return", Integer.toString(taskIndex));
            return result;
        } catch (RuntimeException failure) {
            traceException("run-exception", failure, task, columnCount);
            throw failure;
        } finally {
            if (builder != null) {
                final PageBuilder pendingBuilder = builder;
                recordOperation("builder-close", () -> pendingBuilder.close());
            }
        }
    }

    @Override
    public ConfigDiff guess(ConfigSource config) {
        trace("guess-entry");
        try {
            ConfigDiff result = Exec.newConfigDiff();
            trace("guess-return");
            return result;
        } catch (RuntimeException failure) {
            traceException("guess-exception", failure);
            throw failure;
        }
    }

    private static Schema recordSchemaConstruction() {
        trace("schema-construct-entry");
        try {
            Schema result = Schema.builder().add("number", Types.DOUBLE).build();
            trace("schema-construct-return");
            return result;
        } catch (RuntimeException failure) {
            traceException("schema-construct-exception", failure);
            throw failure;
        }
    }

    private static void traceSchema(String phase, Schema schema) {
        Column column = schema.getColumn(0);
        trace("schema-column", phase, Integer.toString(column.getIndex()), column.getName(), column.getType().getName());
    }

    private static void writeFixture(PageBuilder builder, Column column) {
        long[] bits;
        if ("finite-null".equals(FIXTURE)) {
            bits = new long[] {
                Double.doubleToRawLongBits(Double.MAX_VALUE), Double.doubleToRawLongBits(-Double.MAX_VALUE),
                Double.doubleToRawLongBits(Double.MIN_VALUE), Double.doubleToRawLongBits(-Double.MIN_VALUE),
                Double.doubleToRawLongBits(0.0d), Double.doubleToRawLongBits(-0.0d)
            };
            trace("input-row-count", "7");
            for (int row = 0; row < bits.length; row++) {
                assignDouble(builder, column, row, bits[row]);
                addRecord(builder, row);
            }
            trace("input-cell", "6", "0", "null", null);
            recordOperation("builder-set-null", new String[] {"6", "0"}, () -> builder.setNull(column));
            addRecord(builder, 6);
            return;
        }
        if ("nonfinite".equals(FIXTURE)) {
            bits = new long[] {
                Double.doubleToRawLongBits(Double.POSITIVE_INFINITY), Double.doubleToRawLongBits(Double.NEGATIVE_INFINITY),
                Double.doubleToRawLongBits(Double.NaN), 0x7ff8000000000042L, 0xfff8000000000042L
            };
            trace("input-row-count", "5");
            for (int row = 0; row < bits.length; row++) {
                assignDouble(builder, column, row, bits[row]);
                addRecord(builder, row);
            }
            return;
        }
        throw new IllegalArgumentException("unknown fixture: " + FIXTURE);
    }

    private static void assignDouble(PageBuilder builder, Column column, int row, long bits) {
        double value = Double.longBitsToDouble(bits);
        String raw = hex(Double.doubleToRawLongBits(value));
        trace("input-cell", Integer.toString(row), "0", "double-bits", raw);
        recordOperation("builder-set-double", new String[] {Integer.toString(row), "0", raw}, () -> builder.setDouble(column, value));
    }

    private static void addRecord(PageBuilder builder, int row) {
        recordOperation("builder-add-record", new String[] {Integer.toString(row)}, () -> builder.addRecord());
    }

    private static final class RecordingOutput implements PageOutput {
        private final Schema schema;
        private final PageReader reader;
        private int pageOrdinal;
        private int totalRows;

        RecordingOutput(Schema schema) {
            this.schema = schema;
            trace("reader-construct-entry");
            try {
                reader = new PageReader(schema);
                trace("reader-construct-return");
            } catch (RuntimeException failure) {
                traceException("reader-construct-exception", failure);
                throw failure;
            }
        }

        @Override
        public void add(Page incomingPage) {
            int pageIndex = pageOrdinal++;
            trace("collector-add-entry", Integer.toString(pageIndex));
            try {
                recordOperation("reader-set-page", new String[] {Integer.toString(pageIndex)}, () -> reader.setPage(incomingPage));
                int pageRow = 0;
                while (true) {
                    trace("reader-next-record-entry", Integer.toString(pageIndex), Integer.toString(pageRow));
                    boolean available;
                    try {
                        available = reader.nextRecord();
                        trace("reader-next-record-return", Integer.toString(pageIndex), Integer.toString(pageRow), Boolean.toString(available));
                    } catch (RuntimeException failure) {
                        traceException("reader-next-record-exception", failure, Integer.toString(pageIndex), Integer.toString(pageRow));
                        throw failure;
                    }
                    if (!available) {
                        break;
                    }
                    readCell(pageIndex, pageRow, totalRows);
                    pageRow++;
                    totalRows++;
                }
                trace("collector-add-return", Integer.toString(pageIndex), Integer.toString(pageRow), Integer.toString(totalRows));
            } catch (RuntimeException failure) {
                traceException("collector-add-exception", failure, Integer.toString(pageIndex));
                throw failure;
            }
        }

        private void readCell(int page, int pageRow, int totalRow) {
            Column column = schema.getColumn(0);
            String[] position = {Integer.toString(page), Integer.toString(pageRow), Integer.toString(totalRow), "0"};
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
                return;
            }
            trace("reader-get-double-entry", position);
            try {
                double value = reader.getDouble(column);
                trace("reader-get-double-return", position[0], position[1], position[2], position[3], hex(Double.doubleToRawLongBits(value)));
            } catch (RuntimeException failure) {
                traceException("reader-get-double-exception", failure, position);
                throw failure;
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
                try {
                    reader.close();
                    trace("reader-close-return", Integer.toString(pageOrdinal), Integer.toString(totalRows));
                } catch (RuntimeException failure) {
                    traceException("reader-close-exception", failure, Integer.toString(pageOrdinal), Integer.toString(totalRows));
                    throw failure;
                }
                trace("collector-close-return", Integer.toString(pageOrdinal), Integer.toString(totalRows));
            } catch (RuntimeException failure) {
                traceException("collector-close-exception", failure, Integer.toString(pageOrdinal), Integer.toString(totalRows));
                throw failure;
            }
        }
    }

    private static String hex(long value) {
        return String.format("%016x", value);
    }

    @FunctionalInterface
    private interface Operation {
        void run();
    }

    private static void recordOperation(String name, Operation operation) {
        recordOperation(name, new String[0], operation);
    }
    private static void recordOperation(String name, String[] values, Operation operation) {
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
        StringBuilder row = new StringBuilder("DOUBLETRACE|").append(FIXTURE).append('|').append(CAPTURE).append('|').append(++sequence).append('|').append(event);
        for (String value : values) {
            row.append('|').append(encode(value));
        }
        System.out.println(row);
        if (System.out.checkError()) {
            throw new EvidenceWriteError("unable to write double observation evidence");
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
