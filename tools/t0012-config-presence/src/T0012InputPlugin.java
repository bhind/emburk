import java.io.DataOutputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.Optional;

import org.embulk.config.Config;
import org.embulk.config.ConfigDefault;
import org.embulk.config.ConfigDiff;
import org.embulk.config.ConfigSource;
import org.embulk.config.Task;
import org.embulk.config.TaskReport;
import org.embulk.config.TaskSource;
import org.embulk.spi.Exec;
import org.embulk.spi.InputPlugin;
import org.embulk.spi.PageOutput;
import org.embulk.spi.Schema;

/**
 * Test-only local input plugin for the T-0012/S01 presence-observation matrix.
 * It is neither distributed nor an admitted Embulk plugin.
 */
public final class T0012InputPlugin implements InputPlugin {
    public interface Required extends Task {
        @Config("field")
        String getField();
    }

    public interface Defaulted extends Task {
        @Config("field")
        @ConfigDefault("\"fallback\"")
        String getField();
    }

    public interface OptionalField extends Task {
        @Config("field")
        @ConfigDefault("null")
        Optional<String> getField();
    }

    @Override
    public ConfigDiff transaction(ConfigSource config, Control control) {
        String declaration = System.getenv("T0012_DECLARATION");
        String state = System.getenv("T0012_STATE");
        String outcome;
        String first;
        String message;
        Class<? extends Task> type = configurationType(declaration);
        try {
            Object value = type.getMethod("getField").invoke(config.loadConfig(type));
            outcome = "SUCCESS";
            first = renderValue(value);
            message = "";
        } catch (InvocationTargetException failure) {
            Throwable cause = failure.getCause();
            if (cause instanceof Error) {
                throw (Error) cause;
            }
            if (!(cause instanceof RuntimeException)) {
                throw new IllegalStateException(cause);
            }
            outcome = "EXCEPTION";
            first = cause.getClass().getName();
            message = cause.getMessage();
        } catch (RuntimeException failure) {
            outcome = "EXCEPTION";
            first = failure.getClass().getName();
            message = failure.getMessage();
        } catch (ReflectiveOperationException failure) {
            throw new IllegalStateException(failure);
        }

        emit(declaration, state, outcome, first, message);
        control.run(Exec.newTaskSource(), Schema.builder().build(), 1);
        return Exec.newConfigDiff();
    }

    @Override
    public ConfigDiff resume(TaskSource taskSource, Schema schema, int taskCount, Control control) {
        return Exec.newConfigDiff();
    }

    @Override
    public void cleanup(TaskSource taskSource, Schema schema, int taskCount, List<TaskReport> reports) {
    }

    @Override
    public TaskReport run(TaskSource taskSource, Schema schema, int taskIndex, PageOutput output) {
        output.finish();
        return Exec.newTaskReport();
    }

    @Override
    public ConfigDiff guess(ConfigSource config) {
        return Exec.newConfigDiff();
    }

    private static Class<? extends Task> configurationType(String declaration) {
        if ("required".equals(declaration)) {
            return Required.class;
        }
        if ("defaulted".equals(declaration)) {
            return Defaulted.class;
        }
        if ("optional".equals(declaration)) {
            return OptionalField.class;
        }
        throw new IllegalArgumentException("unknown declaration: " + declaration);
    }

    private static String renderValue(Object value) {
        if (value instanceof Optional) {
            Optional<?> optional = (Optional<?>) value;
            return optional.isPresent() ? "present:" + optional.get() : "empty";
        }
        return value == null ? null : value.toString();
    }

    private static void emit(String declaration, String state, String outcome, String first, String message) {
        writeRawObservation(declaration, state, outcome, first, message);
        System.out.println("CASE|" + declaration + "|" + state + "|" + outcome + "|"
                + encode(first) + "|" + encode(message));
    }

    private static void writeRawObservation(
            String declaration, String state, String outcome, String first, String message) {
        try (DataOutputStream raw = new DataOutputStream(
                new FileOutputStream(System.getenv("T0012_RAW_FILE"), true))) {
            raw.writeUTF(declaration);
            raw.writeUTF(state);
            raw.writeUTF(outcome);
            writeNullable(raw, first);
            writeNullable(raw, message);
        } catch (IOException failure) {
            throw new IllegalStateException(failure);
        }
    }

    private static void writeNullable(DataOutputStream output, String value) throws IOException {
        output.writeBoolean(value == null);
        if (value != null) {
            output.writeUTF(value);
        }
    }

    private static String encode(String value) {
        return value == null ? "-"
                : Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
    }
}
