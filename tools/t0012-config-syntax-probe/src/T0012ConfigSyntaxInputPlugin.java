import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.UUID;
import org.embulk.config.*;
import org.embulk.spi.*;

/** Local Stage A observer for selected input bytes; it defines no product policy. */
public final class T0012ConfigSyntaxInputPlugin implements InputPlugin {
  public interface ConfigTask extends Task { @Config("field") String getField(); }
  private static final String CASE = System.getenv("T0012_SYNTAX_CASE");
  private static final String INVOCATION = System.getenv("T0012_SYNTAX_INVOCATION");
  private static final String CONTEXT = UUID.randomUUID().toString();
  private static int sequence;

  private static String encoded(String value) {
    return value == null ? "-" : Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
  }

  private static void event(String name, String... values) {
    StringBuilder line = new StringBuilder("SYNTAXTRACE|").append(CASE).append('|')
        .append(INVOCATION).append('|').append(CONTEXT).append('|').append(++sequence).append('|').append(name);
    for (String value : values) line.append('|').append(encoded(value));
    System.out.println(line);
  }

  public ConfigDiff transaction(ConfigSource config, Control control) {
    event("transaction-entry");
    event("config-load-entry");
    try {
      event("config-value", config.loadConfig(ConfigTask.class).getField());
    } catch (RuntimeException failure) {
      event("config-exception", failure.getClass().getName(), failure.getMessage());
      throw failure;
    }
    try {
      event("control-entry");
      control.run(Exec.newTaskSource(), Schema.builder().build(), 1);
      event("control-return");
    } catch (RuntimeException failure) {
      event("callback-exception", failure.getClass().getName(), failure.getMessage());
      throw failure;
    }
    event("transaction-return");
    return Exec.newConfigDiff();
  }

  public ConfigDiff resume(TaskSource task, Schema schema, int tasks, Control control) { return Exec.newConfigDiff(); }
  public void cleanup(TaskSource task, Schema schema, int tasks, List<TaskReport> reports) { event("cleanup-entry"); event("cleanup-return"); }
  public TaskReport run(TaskSource task, Schema schema, int index, PageOutput output) {
    event("run-entry"); event("finish-entry"); output.finish(); event("finish-return"); event("run-return"); return Exec.newTaskReport();
  }
  public ConfigDiff guess(ConfigSource config) { return Exec.newConfigDiff(); }
}
