![Brisk](/Assets/Banner.png)

Swift support for blocks and asynchronous code is powerful, but can lead to a maze of indented logic that
quickly becomes unreadable and error-prone.

Brisk offers two distinct but complimentary functions:

1. Extends the standard GCD library with several functions that help make standard usage a bit more concise.
2. Provides shorthand operators for swiveling the concurrency of your functions.

These might be best explained by code example.

### Quick Look: Extending the GCD Library for Simplicity ###

Consider the existing methods required from the standard GCD library:

```swift
// Dispatch a block to the main queue
dispatch_async(dispatch_get_main_queue()) {
    // ...
}

// Dispatch a block to the main queue after 2.0 seconds
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2.0 * Double(NSEC_PER_SEC))),
               dispatch_get_main_queue()) {
    // ...
}
```

Compared to their Brisk equivalents:

```swift
// Dispatch a block to the main queue
dispatch_main_async {
    // ...
}

// Dispatch a block to the main queue after 2.0 seconds
dispatch_main_after(2.0) {
    // ...
}
```

Brisk offers this type of simplification for many standard GCD use cases.

### Quick Look: Concurrency Swiveling ###

Consider the following hypothetical asynchronous API (using Swift 2.2 function syntax):

```swift
// API we're given:
func findClosestPokemonWithin(within: Double,
                   completionHandler: (pokemon: Pokemon?, error: NSError?))

func countPokeballs(completionHandler: (number: Int?, error: NSError?))

func throwPokeballAtPokemon(pokemon: Pokemon,
                  completionHandler: (success: Bool, error: NSError?))
```

Let's assume that all of the completion handlers are called on the main thread.  We want to
make this utility function:

```swift
// Utility we want:
func throwPokeballAtClosestPokemonWithin(within: Double,
                              completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?))
```

This function represents a common occurrence of chaining asynchronous functions into a helper utility for a single use case.
Using only the standard GCD library, your function might look like this:

```swift
// The old way...
func throwPokeballAtClosestPokemonWithin(within: Double,
                              completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?)) {
    // Step 1
    findClosestPokemonWithin(within) { pokemon, error in
        guard let p = pokemon where error == nil else {
            dispatch_main_async {
                completionHandler(success: false, pokemon: nil, error: error)
            }
            return
        }

        // Step 2
        countPokeballs { number, error in
            guard let n = number where error == nil else {
                dispatch_main_async {
                    completionHandler(success: false, pokemon: nil, error: error)
                }
                return
            }

            // Step 3
            throwPokeballAtPokemon(p) { success, error in
                dispatch_main_async {
                    completionHandler(success: success, error: error)
                }
            }
        }
    }
}
```

With Brisk:

```swift
// The new way...
func throwPokeballAtClosestPokemonWithin(within: Double,
                              completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?)) {
    dispatch_bg_async {

        // Step 1
        let (pokemon, error) <<+{ findClosestPokemonWithin(within, completionHandler: $0) }
        guard let p = pokemon where error == nil else {
            return completionHandler +>> (success: false, error: error)
        }

        // Step 2
        let (number, error2) <<+{ countPokeballs($0) }
        guard let n = number where error == nil else {
            return completionHandler +>> (success: false, error: error2)
        }

        // Step 3
        let (success, error3) <<+{ throwPokeballAtPokemon(p, completionHandler: $0) }
        completionHandler +>> (success: success, error: error3)
    }
}
```

The main advantage with Brisk is that the asynchronous functions can be coded using a seemingly-synchronous flow.
The asynchronous nature of the methods is hidden behind the custom operators.  *Unlike PromiseKit, all return values
remain in scope as well*.

# Detailed GCD Additions #

The following code examples show the GCD additions provided by Brisk.  These are
fairly self-documenting.  More information about each method can be found in its comment section.

```swift
dispatch_main_async {
    // Block runs on the main queue
}

dispatch_main_sync {
    // Block runs on the main queue; this function does not return until
    // the block completes.
}

dispatch_bg_async {
    // Block runs on the global concurrent background queue
}

dispatch_async("myNewQueue") {
    // Block runs on a brisk-created serial queue with the specified string ID.
    // Calling this function multiple times with the same string will reuse the
    // named queue.  Useful for dynamic throw-away serial queues.
}

dispatch_main_after(2.0) {
dispatch_after(2.0, myQueue) {
    // Block is called on specified queue after specified number of seconds using
    // a loose leeway (+/- 0.1 seconds).
}

dispatch_main_after_exactly(2.0) {
dispatch_after_exactly(2.0, myQueue) {
    // Block is called on specified queue after specified number of seconds using
    // as tight a timer leeway as possible.  Useful for animation timing but
    // uses more battery power.
}

dispatch_main_every(2.0) { timer in
dispatch_every(2.0, myQueue) { timer in
dispatch_main_every_exact(2.0) { timer in
dispatch_every_exact(2.0, myQueue) { timer in
    // Block is run on specified thread every N seconds.
    // Stop the timer with:
    dispatch_source_cancel(timer)
}

dispatch_main_once_after(2.0, "myOperationId") {
dispatch_once_after(2.0, myQueue, "myOperationId") {
    // Block runs after specified time on specified queue.  The block is
    // only executed ONCE -- repeat calls to this function with the same
    // operation ID will reset its internal timer instead of calling the
    // block again.  Useful for calling a completion block after several
    // disparate asynchronous methods (e.g. saving the database to disk
    // after downloading multiple records on separate threads.)
}

dispatch_each(myArray, myQueue) { element in
    // Each element in the array has this block called with it as a parameter.
    // Should be used on a concurrent queue.
}
```
