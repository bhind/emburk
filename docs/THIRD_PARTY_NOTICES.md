# Third-party notices

This is a development attribution record, not a complete release notice bundle
or SBOM. Cargo.lock and provenance packets identify selected dependencies.
Release packaging must reconcile all distributed code, licenses and notices.
No Embulk implementation source is copied into this project.

T-0025/S02 uses sha2 0.11.0 (MIT/Apache-2.0) as an unmodified dependency for
private checkpoint content hashes. Exact transitive versions/checksums are
locked; [the packet](provenance/T-0025-validated-resume.md) records archive
admission and the offline cache. Hashes detect content changes; they do not
authenticate state against a malicious same-UID writer. Full release notice
bundling, security review and patent/FTO remain unreviewed.

## libbz2-rs-sys 0.2.5

The unmodified dependency is used through bzip2 0.6.1. The following license
text is retained from libbz2-rs-sys-0.2.5/LICENSE, package SHA256
34b357333733e8260735ba5894eb928c02ecc69c78715f01a8019e7fa7f2db4c.

```text
The original program, "bzip2", the associated library "libbzip2", and all
documentation, are

Copyright (C) 1996-2021 Julian R Seward.
Copyright (C) 2019-2020 Federico Mena Quintero
Copyright (C) 2021 Micah Snyder

This Rust translation, "libbzip2-rs" is a derived work based on "bzip2" and
"libbzip2", and is Copyright (C) 2024-2025 Trifecta Tech Foundation and contributors

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

2. The origin of this software must not be misrepresented; you must
   not claim that you wrote the original software.  If you use this
   software in a product, an acknowledgment in the product
   documentation would be appreciated but is not required.

3. Altered source versions must be plainly marked as such, and must
   not be misrepresented as being the original software.

4. The name of the author may not be used to endorse or promote
   products derived from this software without specific prior written
   permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Julian Seward, jseward@acm.org
bzip2/libbzip2 version 1.1.0 of 6 September 2010
```
