
# Runner

Support for executing subprocesses, using Foundation.Process, and capturing their
output asynchronously. Swift 6 ready.

Usage examples:

### Run And Capture Stdout

```swift

let url = /* url to the executable */
let runner = Runner(for: url)

// execute with some arguments
let session = runner.run(["some", "arguments"])

// process the output asynchronously
for await l in result.stdout.lines {
  print(l)
}
```

### Run In A Different Working Directory

```swift
// run in a different working directory
runner.cwd = /* url to the directory */
let _ = runner.run(["blah"])
```

### Transfer Execution

```swift
// transfer execution to the subprocess
runner.exec(url)
```

## Lookup Executable In Path

```swift

let runner = Runner(command: "git") /// we'll find git in $PATH if it's there
let session = runner.run("status")
print(await session.stdout.string)
```


### Run And Wait For Termination

```swift
let url = /* url to the executable */
let runner = Runner(for: url)

// execute with some arguments
let session = runner.run(["some", "arguments"])

// wait for termination and read state
if await session.waitUntilExit() == .succeeded {
  print("all good")
}
```

### Run Passing Stdout/Stderr Through

```swift
let url = /* url to the executable */
let runner = Runner(for: url)
let session = runner.run(stdoutMode: .forward, stderrMode: .forward)
let _ = session.waitUntilExit()
```