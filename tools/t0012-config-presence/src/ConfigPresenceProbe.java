import java.io.DataOutputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Optional;
import org.embulk.config.Config;
import org.embulk.config.ConfigDefault;
import org.embulk.config.ConfigLoader;
import org.embulk.config.ConfigSource;
import org.embulk.config.ModelManager;
import org.embulk.config.Task;

/** A small, independent observation probe; this is not derived from Embulk sources or tests. */
public final class ConfigPresenceProbe {
    public interface Required extends Task {
        @Config("field") String getField();
    }

    public interface Defaulted extends Task {
        @Config("field") @ConfigDefault("\"fallback\"") String getField();
    }

    public interface OptionalField extends Task {
        @Config("field") @ConfigDefault("null") Optional<String> getField();
    }

    private static final String[] STATES = {"absent", "null", "value"};

    private static ConfigLoader loader;
    private static DataOutputStream raw;

    public static void main(String[] args) throws Exception {
        if (args.length != 1) throw new IllegalArgumentException("expected raw-observation output path");
        loader = new ConfigLoader(new ModelManager());
        raw = new DataOutputStream(new FileOutputStream(args[0]));
        for (String state : STATES) {
            observe("required", state, Required.class);
            observe("defaulted", state, Defaulted.class);
            observe("optional", state, OptionalField.class);
        }
        raw.close();
    }

    private static void observe(String declaration, String state, Class<? extends Task> type)
            throws ReflectiveOperationException {
        String outcome;
        String first;
        String second;
        try {
            ConfigSource source = loader.fromYamlString(yamlFor(state));
            Object configured = source.loadConfig(type);
            Object field = type.getMethod("getField").invoke(configured);
            String rawValue = field instanceof Optional
                    ? (((Optional<?>) field).isPresent() ? "present:" + ((Optional<?>) field).get() : "empty")
                    : (field == null ? null : field.toString());
            outcome = "SUCCESS";
            first = rawValue;
            second = "";
        } catch (InvocationTargetException failure) {
            Throwable target = failure.getCause();
            if (target instanceof Error) {
                throw (Error) target;
            }
            if (!(target instanceof RuntimeException)) {
                throw failure;
            }
            outcome = "EXCEPTION";
            first = target.getClass().getName();
            second = target.getMessage();
        } catch (RuntimeException failure) {
            outcome = "EXCEPTION";
            first = failure.getClass().getName();
            second = failure.getMessage();
        }
        emit(declaration, state, outcome, first, second);
    }

    private static String yamlFor(String state) {
        if (state.equals("absent")) return "{}\n";
        if (state.equals("null")) return "field: null\n";
        return "field: observed-value\n";
    }

    private static void emit(String declaration, String state, String outcome, String first, String second) {
        try {
            raw.writeUTF(declaration);
            raw.writeUTF(state);
            raw.writeUTF(outcome);
            writeNullable(first);
            writeNullable(second);
            raw.flush();
        } catch (IOException failure) {
            throw new IllegalStateException("could not preserve raw observation", failure);
        }
        System.out.println("CASE|" + declaration + "|" + state + "|" + outcome + "|"
                + encoded(first) + "|" + encoded(second));
    }

    private static void writeNullable(String value) throws IOException {
        raw.writeBoolean(value == null);
        if (value != null) raw.writeUTF(value);
    }

    private static String encoded(String value) {
        return value == null ? "-" : Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
    }
}
