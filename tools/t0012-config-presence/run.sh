#!/usr/bin/env bash
set -euo pipefail

# Independently authored T-0012/S01 reference-observation runner.  It does not
# build Embulk from source and deliberately keeps all runtime material outside
# the repository.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
probe_source="$script_dir/src/ConfigPresenceProbe.java"
gradle_version=8.10.2
gradle_url="https://downloads.gradle.org/distributions/gradle-${gradle_version}-bin.zip"
gradle_sha256='31c55713e40233a8303827ceb42ca48a47267a0ad4bab9177123121e71524c26'
temp_root=${T0012_TEMP_ROOT:-"${TMPDIR:-/private/tmp}/t0012-config-presence-runtime"}

case "$temp_root" in
  /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*) ;;
  *) printf '%s\n' "T0012_TEMP_ROOT must be a temporary directory outside the repository" >&2; exit 2 ;;
esac

mkdir -p -- "$temp_root"
[[ ! -L "$temp_root" ]] || { printf '%s\n' 'T0012_TEMP_ROOT must not be a symlink' >&2; exit 2; }
run_dir=$(mktemp -d "$temp_root/run.XXXXXX")
evidence_dir="$run_dir/evidence"
project_dir="$run_dir/project"
mkdir -p -- "$evidence_dir" "$project_dir/src/main/java"
trap 'printf "T0012_EVIDENCE_DIR=%s\\n" "$evidence_dir"' EXIT

if [[ ! -f "$probe_source" ]]; then
  printf '%s\n' "missing probe source: $probe_source" >&2
  exit 2
fi

gradle_zip="$run_dir/gradle-${gradle_version}-bin.zip"
gradle_checksum="$run_dir/gradle-${gradle_version}-bin.zip.sha256"
gradle_home="$run_dir/gradle-${gradle_version}"
command -v curl >/dev/null || { printf '%s\n' "curl is required to fetch Gradle" >&2; exit 2; }
curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error --output "$gradle_zip" "$gradle_url"
curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error --output "$gradle_checksum" "${gradle_url}.sha256"
expected_gradle_hash=$(awk '{print $1}' "$gradle_checksum")
actual_gradle_hash=$(shasum -a 256 "$gradle_zip" | awk '{print $1}')
[[ "$expected_gradle_hash" == "$gradle_sha256" && "$actual_gradle_hash" == "$gradle_sha256" ]] || { printf '%s\n' 'Gradle distribution checksum mismatch' >&2; exit 3; }
printf '%s|%s\n' "$gradle_version" "$actual_gradle_hash" > "$evidence_dir/gradle-distribution.sha256"
unzip -q "$gradle_zip" -d "$run_dir"
[[ -x "$gradle_home/bin/gradle" ]] || { printf '%s\n' 'verified Gradle distribution did not unpack as expected' >&2; exit 3; }
export GRADLE_USER_HOME="$run_dir/gradle-user-home"

cp -- "$probe_source" "$project_dir/src/main/java/ConfigPresenceProbe.java"
cat > "$project_dir/settings.gradle" <<'EOF'
rootProject.name = 't0012-config-presence-probe'
EOF
cat > "$project_dir/build.gradle" <<'EOF'
plugins { id 'application' }
repositories { maven { url = uri('https://repo1.maven.org/maven2/') } }
dependencies { implementation 'org.embulk:embulk-core:0.11.5' }
application { mainClass = 'ConfigPresenceProbe' }
run {
  doFirst {
    if (!project.hasProperty('probeEvidence')) throw new GradleException('probeEvidence is required')
    args(project.property('probeEvidence'))
  }
}
tasks.register('recordRuntime') {
  doLast {
    configurations.runtimeClasspath.resolvedConfiguration.resolvedArtifacts.each { artifact ->
      def id = artifact.moduleVersion.id
      def digest = java.security.MessageDigest.getInstance('SHA-256')
      artifact.file.withInputStream { input ->
        byte[] buffer = new byte[8192]
        for (int read; (read = input.read(buffer)) != -1;) digest.update(buffer, 0, read)
      }
      println("RESOLVED|${id.group}:${id.name}:${id.version}|${artifact.file.name}|" + digest.digest().collect { String.format('%02x', it) }.join())
    }
  }
}
EOF

"$gradle_home/bin/gradle" -p "$project_dir" --no-daemon --version > "$evidence_dir/gradle-version.txt"
java -XshowSettings:properties -version > "$evidence_dir/java-version.txt" 2>&1
uname -s > "$evidence_dir/os-family.txt"
shasum -a 256 "$probe_source" | awk '{print $1}' > "$evidence_dir/probe-source.sha256"
printf '%s\n' 'org.embulk:embulk-core:0.11.5' > "$evidence_dir/requested-coordinate.txt"

"$gradle_home/bin/gradle" -p "$project_dir" --no-daemon --console=plain recordRuntime > "$evidence_dir/resolved-artifacts.raw" 2>&1
if ! grep -Eq '^RESOLVED\|org\.embulk:embulk-core:0\.11\.5\|embulk-core-0\.11\.5\.jar\|[0-9a-f]{64}$' "$evidence_dir/resolved-artifacts.raw"; then
  printf '%s\n' 'pinned embulk-core identity was not resolved' >&2
  exit 3
fi
grep '^RESOLVED|' "$evidence_dir/resolved-artifacts.raw" > "$evidence_dir/resolved-jars.sha256" || true
[[ -s "$evidence_dir/resolved-jars.sha256" ]] || { printf '%s\n' 'no runtime jar checksums recorded' >&2; exit 3; }

"$gradle_home/bin/gradle" -p "$project_dir" --no-daemon --console=plain clean run "-PprobeEvidence=$evidence_dir/observations.raw.bin" > "$evidence_dir/probe-output.raw" 2>&1
grep '^CASE|' "$evidence_dir/probe-output.raw" > "$evidence_dir/cases.raw" || true
case_count=$(wc -l < "$evidence_dir/cases.raw" | tr -d ' ')
if [[ "$case_count" != 9 ]]; then
  printf 'expected 9 complete runtime case rows, found %s\n' "$case_count" >&2
  exit 4
fi
if grep -Ev '^CASE\|(required|defaulted|optional)\|(absent|null|value)\|(SUCCESS|EXCEPTION)\|([A-Za-z0-9+/=]*|-)\|([A-Za-z0-9+/=]*|-)$' "$evidence_dir/cases.raw" >/dev/null; then
  printf '%s\n' 'one or more case rows is incomplete' >&2
  exit 4
fi
[[ -s "$evidence_dir/observations.raw.bin" ]] || { printf '%s\n' 'reversible raw observation file was not created' >&2; exit 4; }
for key in required:absent required:null required:value defaulted:absent defaulted:null defaulted:value optional:absent optional:null optional:value; do
  declaration=${key%%:*}; state=${key##*:}
  [[ $(grep -Ec "^CASE\\|${declaration}\\|${state}\\|" "$evidence_dir/cases.raw") == 1 ]] || {
    printf 'missing or duplicate case key: %s\n' "$key" >&2; exit 4;
  }
done
for declaration in required defaulted; do
  grep -Fqx "CASE|$declaration|value|SUCCESS|b2JzZXJ2ZWQtdmFsdWU=|" "$evidence_dir/cases.raw" || {
    printf 'known-value control did not succeed: %s\n' "$declaration" >&2; exit 4;
  }
done
grep -Fqx 'CASE|optional|value|SUCCESS|cHJlc2VudDpvYnNlcnZlZC12YWx1ZQ==|' "$evidence_dir/cases.raw" || {
  printf '%s\n' 'known-value control did not succeed: optional'; exit 4;
}
cat "$evidence_dir/cases.raw"
