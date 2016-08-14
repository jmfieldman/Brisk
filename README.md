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
                   completionHandler: (pokemon: Pokemon?, error: NSError?) -> Void)

func countPokeballs(completionHandler: (number: Int?, error: NSError?) -> Void)

func throwPokeballAtPokemon(pokemon: Pokemon,
                  completionHandler: (success: Bool, error: NSError?) -> Void)
```

Let's assume that all of the completion handlers are called on the main thread.  We want to
make this utility function:

```swift
// Utility we want:
func throwAtClosestPokemonWithin(within: Double,
                      completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?) -> Void)
```

This function represents a common occurrence of chaining asynchronous functions into a helper utility for a single use case.
Using only the standard GCD library, your function might look like this:

```swift
// The old way...
func throwAtClosestPokemonWithin(within: Double,
                      completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?) -> Void) {
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
func throwAtClosestPokemonWithin(within: Double,
                      completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?) -> Void) {
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

# Making Functions Synchronous #

This section refers the idea of taking a naturally asynchronous function and calling
it synchronously, generally for the purpose of chaining multiple asynchronous
operations.  This is essentially the same offering of PromiseKit but without
the needless indentation and scope shuffle that comes with it.

To see a practical use case, refer to the Quick Look example at the beginning of
this document.

When we talk about an asynchronous function, it must abide by these characteristics:

* Returns ```Void```
* Takes any number of input parameters
* Has a single "completion" parameter that takes a function of the form ```(...) -> Void```

These are all examples of suitable asynchronous functions:

```swift
func getAlbum(named: String, handler: (album: PhotoAlbum?, error: NSError?) -> Void)
func saveUser(completionHandler: (success: Bool) -> Void)
func verifyUser(name: String, password: String, completion: (valid: Bool) -> Void)

// Typical use of a function would look like:
getAlbum("pics") { photo, error in
    // ...
}
```

With Brisk, you can use the <<+, <<~ or <<- operators to call your function in
a way that blocks the calling thread until your function has called its completion
handler.

```swift
// <<+ will execute getAlbum on the main queue
let (album, error) = <<+{ getAlbum("pics", handler: $0) }

// <<~ will execute saveUser on the global concurrent background queue
let success        = <<~{ saveUser($0) }

// <<- will execute verifyUser immediately in the current queue (note that the
//     current thread will wait for the completion handler to be called before
//     returning the final value.)
let valid          = <<-{ verifyUser("myname", password: "mypass", completion: $0) }

// You can also specify *any* queue you want.  Here saveUser is called on myQueue.
let myQueue        = dispatch_queue_create("myQueue", nil)
let valid          = <<~myQueue ~~~ { saveUser($0) }
```

In all of the above examples, execution of the outer thread is paused until the completion
handler ```$0``` is called.  Once ```$0``` is called, the values passed into it are routed back
to the original assignment operation.

Note that the ```$0``` handler can accommodate any number of parameters (e.g. ```getAlbum```
above can take ```album``` and ```error```), but it must be assigned to variables that
create the same tuple.  Also note that it is not possible to extract ```NSError``` parameters
to transform them into do/try/catch methodology -- you will have to check the ```NSError```
as part of the returned tuple.

Also note that the outer thread WILL PAUSE until ```$0``` is called.  This means that
Brisk can only be used for functions that guarantee their completion handlers will
be called at some deterministic point in the future.  It is not suitable for open-ended
asynchronous functions like ```NSNotification``` handlers.
