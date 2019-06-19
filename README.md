# Runner

Some basic support for executing subprocesses, using Foundation.Process.

Usage:

```swift

let url = /* url to the executable */
let runner = Runner(for: url)

// execute and wait for results
let result = runner.sync(["some", "arguments"])
print(result.status)
print(result.stdout)
print(result.stderr)


// run in a different working directory
runner.cwd = /* url to the directory */
let _ = runner.sync(["blah"])

// transfer execution to the subprocess
runner.exec(url)
```

## Path Lookup

Rather than supplying the path to the executable explicitly,
you can instead supply just a name, and have it looked up using
the $PATH environment variable.

```swift

let runner = Runner(command: "name")
```
