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
