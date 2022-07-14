[comment]: <> (Header Generated by ActionStatus 2.0 - 395)

[![Test results][tests shield]][actions] [![Latest release][release shield]][releases] [![swift 5.1 shield] ![swift 5.2 shield] ![swift 5.3 shield] ![swift dev shield]][swift] ![Platforms: macOS, Linux][platforms shield]

[release shield]: https://img.shields.io/github/v/release/elegantchaos/Runner
[platforms shield]: https://img.shields.io/badge/platforms-macOS_Linux-lightgrey.svg?style=flat "macOS, Linux"
[tests shield]: https://github.com/elegantchaos/Runner/workflows/Tests/badge.svg
[swift 5.1 shield]: https://img.shields.io/badge/swift-5.1-F05138.svg "Swift 5.1"
[swift 5.2 shield]: https://img.shields.io/badge/swift-5.2-F05138.svg "Swift 5.2"
[swift 5.3 shield]: https://img.shields.io/badge/swift-5.3-F05138.svg "Swift 5.3"
[swift dev shield]: https://img.shields.io/badge/swift-dev-F05138.svg "Swift dev"

[swift]: https://swift.org
[releases]: https://github.com/elegantchaos/Runner/releases
[actions]: https://github.com/elegantchaos/Runner/actions

[comment]: <> (End of ActionStatus Header)

# Runner

Some basic support for executing subprocesses, using Foundation.Process.

To initialise a Runner, you pass it a command to execute, and
optionally a working directory and some environment variables.

You can then invoke the command (multiple times if you need).
For each invocation you pass some arguments, and also the mode
to use for capturing output (stdout and stderr) from the process.

Invocation can be done synchronously or asynchronously.

## Usage

```swift

let url = /* url to the executable */
let runner = Runner(for: url)

// execute and wait for completion, capturing the results
let result = runner.sync(["some", "arguments"])
print(result.status)
print(result.stdout)
print(result.stderr)

// execute in the background, with a callback to process output
let runningProcess = runner.async(["some", "arguments"], stdoutMode: .callback { print($0) })

// run with a custom environment and working directory
let runner = Runner(for: url, cwd: customURL, environment: ["foo": "bar"])
print(result.status)

// transfer execution to the subprocess
runner.exec(["some", "arguments"])
```

## Path Lookup

Rather than supplying the path to the executable explicitly,
you can instead supply just a name, and have it looked up using
the $PATH environment variable.

```swift

let runner = Runner(command: "name")
```

## Output Modes

Runner accepts two arguments which control how the `stdout` and `stderr` output streams are handled.

These can be configured to do one of the following:

- `passthrough`: just send the output to the real stdout/stderr
- `capture`: capture the output in the `Result` structure
- `tee`: both of the above
- `callback`: execute a block whenever new output is received

## Async/Await Support

Coming soon to this branch...
