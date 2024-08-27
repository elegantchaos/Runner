
# Runner

Support for executing subprocesses, using Foundation.Process, and capturing their
output asynchronously. Swift 6 ready.

Usage:

```swift

let url = /* url to the executable */
let runner = Runner(for: url)

// execute with some arguments
let session = runner.run(["some", "arguments"])

// process the output
for await l in result.stdout.lines {
  print(l)
}


// run in a different working directory
runner.cwd = /* url to the directory */
let _ = runner.run(["blah"])

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
