import java.util.List;
import java.util.UUID;
import java.util.Base64;
import org.embulk.config.*;
import org.embulk.spi.*;

/** Original, local-only Stage A observer. It defines no product policy. */
public final class T0012ConfigEnvelopeInputPlugin implements InputPlugin {
  public interface ConfigTask extends Task { @Config("field") String getField(); }
  private static final String CASE = System.getenv("T0012_ENVELOPE_CASE");
  private static final String INVOCATION = System.getenv("T0012_ENVELOPE_INVOCATION");
  private static final String CONTEXT = UUID.randomUUID().toString();
  private static int sequence;
  private static String b(String s) { return s == null ? "-" : Base64.getEncoder().encodeToString(s.getBytes(java.nio.charset.StandardCharsets.UTF_8)); }
  private static void event(String name, String... values) {
    StringBuilder line = new StringBuilder("ENVELOPETRACE|").append(CASE).append('|').append(INVOCATION).append('|').append(CONTEXT).append('|').append(++sequence).append('|').append(name);
    for (String value : values) line.append('|').append(b(value)); System.out.println(line);
  }
  public ConfigDiff transaction(ConfigSource config, Control control) {
    event("transaction-entry"); event("config-load-entry");
    try { event("config-value", config.loadConfig(ConfigTask.class).getField()); }
    catch (RuntimeException failure) { event("config-exception", failure.getClass().getName(), failure.getMessage()); throw failure; }
    try { event("control-entry"); control.run(Exec.newTaskSource(), Schema.builder().build(), 1); event("control-return"); }
    catch (RuntimeException failure) { event("callback-exception", failure.getClass().getName(), failure.getMessage()); throw failure; }
    event("transaction-return"); return Exec.newConfigDiff();
  }
  public ConfigDiff resume(TaskSource t, Schema s, int n, Control c) { return Exec.newConfigDiff(); }
  public void cleanup(TaskSource t, Schema s, int n, List<TaskReport> r) { event("cleanup-entry"); event("cleanup-return"); }
  public TaskReport run(TaskSource t, Schema s, int i, PageOutput o) { event("run-entry"); event("finish-entry"); o.finish(); event("finish-return"); event("run-return"); return Exec.newTaskReport(); }
  public ConfigDiff guess(ConfigSource c) { return Exec.newConfigDiff(); }
}
