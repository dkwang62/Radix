# Restore Rollback Interruption Probe

This standalone probe exercises `RestoreRollbackJournal` across real process
termination. It uses synthetic SQLite, preference and image stand-ins in a
temporary directory; it never opens Radix user data.

```sh
mkdir -p .build/RestoreRollbackProbe
xcrun swiftc Models/RestoreRollbackJournal.swift Tests/RestoreRollbackProbe/Probe.swift \
  -o .build/RestoreRollbackProbe/restore-rollback-probe
ruby Tests/RestoreRollbackProbe/run.rb .build/RestoreRollbackProbe/restore-rollback-probe
```

Five cases kill after durable intent or after each incoming store mutation.
Four more kill after each rollback store write. Every relaunch must restore the
exact original bytes, retire intent only after completion and remain idempotent.
The probe verifies journal durability and replay ordering; it does not replace
physical-device testing of the shipping backup UI or storage-exhaustion faults.
